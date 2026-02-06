package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"log/slog"
	"net/http"
	"os"
	"path/filepath"
	"reflect"
	"runtime"
	"strconv"
	"strings"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/collectors"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/tarantool/go-storage"
	"github.com/tarantool/go-storage/driver/etcd"
	"github.com/tarantool/go-tarantool/v2"
	"github.com/tarantool/go-tarantool/v2/crud"
	"github.com/tarantool/go-tlog"
	clientv3 "go.etcd.io/etcd/client/v3"
	"gopkg.in/yaml.v3"

	"github.com/tarantool/go-discovery"
	"github.com/tarantool/go-discovery/dial"
	"github.com/tarantool/go-discovery/discoverer"
	"github.com/tarantool/go-discovery/filter"
	"github.com/tarantool/go-discovery/pool"
	"github.com/tarantool/go-discovery/scheduler"
	"github.com/tarantool/go-discovery/subscriber"
)

var startTime = time.Now()

func main() {
	tlogger, err := tlog.New(tlog.Opts{
		Level:  tlog.LevelInfo,
		Format: tlog.FormatText,
		Path:   "stdout",
	})
	if err != nil {
		log.Fatalf("failed to create logger: %s", err)
	}
	defer tlogger.Close()

	logger := tlogger.Logger()

	// Read enviroment variables to connect to config storage.
	WorkerStartCfg := WorkerStartCfg{}
	err = WorkerStartCfg.ReadEnv()
	if err != nil {
		logger.Error("failed read config storage config", "err", err)
		return
	}

	logger.Debug("read configuration from env")

	// Connect to etcd to retrieve workers configuration.
	clientv3, err := clientv3.New(clientv3.Config{
		Endpoints: WorkerStartCfg.EtcdEndpoints,
	})
	if err != nil {
		logger.Error("unable to start etcd client", "err", err)
		return
	}
	defer clientv3.Close()

	driver := etcd.New(clientv3)

	baseStorage := storage.NewStorage(driver)

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	workerCfg, err := getWorkerConfig(
		ctx,
		baseStorage,
		WorkerStartCfg,
	)
	if err != nil {
		logger.Error("failed to get worker's config", "err", err)
		return
	}

	// Create pool for tarantool cluster.
	pool, err := pool.NewPool(
		dial.NewNetDialerFactory(
			workerCfg.Config.TarantoolUser,
			workerCfg.Config.TarantoolPass,
			tarantool.Opts{
				Timeout: 5 * time.Second,
			},
		),
		pool.NewRoundRobinBalancer(),
	)

	if err != nil {
		logger.Error("failed to create a pool", "err", err)
		return
	}

	// The scheduler will watch for updates from etcd.
	etcdWatcher := scheduler.NewEtcdWatch(
		clientv3,
		workerCfg.Config.TarantoolClusterPrefix,
	)
	defer etcdWatcher.Stop()

	disc := discoverer.NewFilter(
		// The base discoverer gets a list of instance configurations from
		// etcd.
		discoverer.NewEtcd(clientv3,
			strings.TrimSuffix(
				workerCfg.Config.TarantoolClusterPrefix,
				"/config/all",
			),
		),
	)

	// The Subscriber will send instance configurations into the pool
	// on updates.
	etcdSubscriber := subscriber.NewFilter(
		subscriber.NewSchedule(etcdWatcher, disc),
		// etcdSubscriber will track new crud-routers in cluster configuration.
		filter.RolesContain{
			Roles: []string{"roles.crud-router"},
		},
	)

	// Subscribe the pool for updates from the subscriber. Subscription
	// only to single subscriber at a moment is supported.
	err = etcdSubscriber.Subscribe(context.Background(), pool)
	if err != nil {
		logger.Error("failed subscribe pool", "err", err)
		return
	}
	defer etcdSubscriber.Unsubscribe(pool)

	err = waitPoolReady(pool, time.Second, 5*time.Second)
	if err != nil {
		logger.Error("pool is not ready", "err", err)
	}

	// Create handler for default golang metrics.
	reg := prometheus.NewRegistry()
	reg.MustRegister(
		collectors.NewProcessCollector(collectors.ProcessCollectorOpts{}),
		collectors.NewGoCollector(),
	)

	metricsMux := http.NewServeMux()
	metricsMux.Handle(
		workerCfg.Instrumentation.MetricsURL,
		promhttp.HandlerFor(reg, promhttp.HandlerOpts{}),
	)

	// Create handler for simple healthcheck.
	metricsMux.HandleFunc(
		workerCfg.Instrumentation.LivenessURL,
		func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(http.StatusOK)
			w.Write([]byte(`{"status":"alive","details":{"memory":"ok"}}`))
		},
	)

	// Create handler for worker information.
	metricsMux.HandleFunc(
		workerCfg.Instrumentation.InfoURL,
		func(w http.ResponseWriter, r *http.Request) {
			var ms runtime.MemStats
			runtime.ReadMemStats(&ms)
			alloc := ms.Alloc
			info := InfoResponse{
				Version:          "0.0.1",
				UptimeSeconds:    time.Since(startTime).Seconds(),
				MemoryUsageBytes: alloc,
				ExtraInfo: map[string]string{
					"AppName": "tdb-worker-example",
				},
			}

			body, err := json.Marshal(info)
			if err != nil {
				w.WriteHeader(http.StatusInternalServerError)
				return
			}

			w.WriteHeader(http.StatusOK)
			w.Write(body)
		},
	)

	go func() {
		logger.Info("starting instrumentation server", "addr", workerCfg.Instrumentation.URL)
		err := http.ListenAndServe(
			workerCfg.Instrumentation.URL,
			metricsMux,
		)
		if err != nil {
			logger.Error("failed to start metrics server", "err", err)
		}
	}()
	h := &HttpHandler{
		Pool:      pool,
		TupleType: reflect.TypeFor[Tuple](),
		Log:       logger,
	}

	// Handle space requests.
	mux := http.NewServeMux()
	mux.HandleFunc("GET /api/bands/{id}", h.Get)
	mux.HandleFunc("POST /api/bands", h.Replace)

	logger.Info("starting http server", "addr", workerCfg.Config.Addr)
	err = http.ListenAndServe(workerCfg.Config.Addr, mux)
	if err != nil {
		logger.Error("failed to start http-server", "err", err)
	}
}

func getWorkerConfig(
	ctx context.Context,
	configStorage storage.Storage,
	startCfg WorkerStartCfg) (*WorkerConfig, error) {

	prefix := filepath.Join(startCfg.EtcdPrefix, "instances", startCfg.HostName)
	fmt.Println(startCfg.WorkerName, prefix)
	resp, err := configStorage.Range(
		ctx,
		storage.WithPrefix(prefix),
	)
	if err != nil {
		return nil, fmt.Errorf("failed read worker config: %s", err)
	}
	if len(resp) == 0 {
		return nil, fmt.Errorf("get no config for workers in path: %s", prefix)
	}

	var cfg WorkerConfig

	for _, r := range resp {
		if string(r.Key) == filepath.Join(prefix, startCfg.WorkerName) {
			err = yaml.Unmarshal(r.Value, &cfg)
			if err != nil {
				return nil, fmt.Errorf("failed unmarshal worker config: %s", err)
			}
			return &cfg, nil
		}
	}

	return nil, fmt.Errorf(
		"get no config for workers in path: %s, %s", prefix, startCfg.WorkerName,
	)
}

func waitPoolReady(
	pool *pool.Pool,
	retry time.Duration,
	timeout time.Duration) error {

	timer := time.NewTimer(timeout)
	defer timer.Stop()
	tik := time.NewTicker(retry)
	defer tik.Stop()

	for {
		select {
		case <-tik.C:
			_, err := pool.Do(
				tarantool.NewPingRequest(),
				discovery.ModeAny,
			).Get()
			if err == nil {
				return nil
			}
		case <-timer.C:
			return fmt.Errorf("failed to connect to tarantool cluster")
		}
	}
}

type WorkerStartCfg struct {
	WorkerName    string
	HostName      string
	EtcdEndpoints []string
	EtcdPrefix    string
}

func (c *WorkerStartCfg) ReadEnv() error {
	var isExists bool
	c.WorkerName, isExists = os.LookupEnv("TDB_WORKER_NAME")
	if !isExists {
		return fmt.Errorf("TDB_WORKER_NAME not set")
	}
	endpoints, isExists := os.LookupEnv("TDB_WORKER_CONFIG_ETCD_ENDPOINTS")
	if !isExists {
		return fmt.Errorf("TDB_WORKER_CONFIG_ETCD_ENDPOINTS not set")
	}
	c.EtcdEndpoints = strings.Split(endpoints, ",")
	c.EtcdPrefix, isExists = os.LookupEnv("TDB_WORKER_CONFIG_ETCD_PREFIX")
	if !isExists {
		return fmt.Errorf("TDB_WORKER_CONFIG_ETCD_PREFIX not set")
	}
	c.HostName, isExists = os.LookupEnv("TDB_WORKER_HOST_NAME")
	if !isExists {
		return fmt.Errorf("TDB_WORKER_HOST_NAME not set")
	}

	return nil
}

type WorkerConfig struct {
	Type            string                `yaml:"type"`
	Instrumentation InstrumentationConfig `yaml:"instrumentation"`
	Config          WorkerRuntimeConfig   `yaml:"config"`
}

type InstrumentationConfig struct {
	URL           string `yaml:"url"`
	MetricsURL    string `yaml:"metrics_url"`
	MetricsFormat string `yaml:"metrics_format"`
	LivenessURL   string `yaml:"liveness_url"`
	InfoURL       string `yaml:"info_url"`
	Binary        string `yaml:"binary"`
}

type WorkerRuntimeConfig struct {
	Addr                   string `yaml:"addr"`
	TarantoolClusterPrefix string `yaml:"tarantool_cluster_prefix"`
	TarantoolUser          string `yaml:"tarantool_user"`
	TarantoolPass          string `yaml:"tarantool_pass"`
}

type Tuple struct {
	_msgpack struct{} `msgpack:",asArray"`
	Id       uint64   `json:"id"`
	BucketId *uint64  `json:"-"`
	BandName string   `json:"band_name"`
	Year     uint64   `json:"year"`
}

type HttpHandler struct {
	Pool      *pool.Pool
	TupleType reflect.Type
	Log       *slog.Logger
}

func (h *HttpHandler) Get(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.Atoi(r.PathValue("id"))
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		return
	}
	request := crud.MakeGetRequest("bands").Key(crud.Tuple([]any{id}))
	res := crud.MakeResult(h.TupleType)
	err = h.Pool.Do(request, discovery.ModeAny).GetTyped(&res)
	h.Log.Info("get request", "id", id)

	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		return
	}

	rows := res.Rows.([]Tuple)
	if len(rows) != 1 {
		w.WriteHeader(http.StatusNotFound)
		return
	}

	body, err := json.Marshal(rows[0])
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write(body)
}

func (h *HttpHandler) Replace(w http.ResponseWriter, r *http.Request) {
	body, err := io.ReadAll(r.Body)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		return
	}

	t := Tuple{}
	err = json.Unmarshal(body, &t)
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		return
	}

	req := crud.MakeReplaceRequest("bands").Tuple(t).Opts(
		crud.SimpleOperationOpts{
			Noreturn: crud.MakeOptBool(true),
		},
	)

	res := crud.MakeResult(h.TupleType)
	err = h.Pool.Do(req, discovery.ModeRW).GetTyped(&res)
	h.Log.Info("replace request", "id`", t.Id)

	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
}

type InfoResponse struct {
	Version          string            `json:"version"`
	UptimeSeconds    float64           `json:"uptime_seconds"`
	MemoryUsageBytes uint64            `json:"memory_usage_bytes"`
	ExtraInfo        map[string]string `json:"extra_info,omitempty"`
}
