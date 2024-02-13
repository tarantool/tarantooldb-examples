[Главная страница](../../../README.md)

# tarantool-java-ee client

Существует два способа получить tarantool-java-ee клиент к tarantool:
1. Загрузить с Nexus (или другое хранилище артефактов) вашей компании
2. Загрузить с клиентской зоны tarantool.io

## Nexus

Вам нужно изменить файл настроек Maven следующим образом:
Обычно он хранится в `~/.m2/settings.xml` или можно изменить локальный файл `setting.xml`.

```xml
<settings>
	<servers>
		<server>
			<id>{name}</id>
			<username>{user_name}</username>
			<password>{password}</password>
		</server>
	</servers>

	<activeProfiles>
		<activeProfile>{name}</activeProfile>
	</activeProfiles>

	<profiles>
		<profile>
			<id>{name}</id>
			<repositories>
				<repository>
					<id>central</id>
					<url>https://repo1.maven.org/maven2</url>
				</repository>
				<repository>
					<id>{name}</id>
					<url>{host}</url>
					<snapshots>
						<enabled>true</enabled>
					</snapshots>
				</repository>
			</repositories>
		</profile>
	</profiles>
</settings>
```

## Customer zone

1. Необходимо зарегистрироваться с рабочей почты компании.
   Так же необходимо, чтобы для почты компании предоставили доступ в клиентскую зону.
2. Скачать артефакты https://www.tarantool.io/en/accounts/customer_zone/packages/maven
   * Скачать вручную с помощью браузера
   * Скачать с помощью REST API и maven

### Как скачать с помощью REST API и maven

1. Воспользоваться API и записать sessionid в settings.xml
    ```bash
    $ USER_NAME=email PASSWORD=password ./write_session_id_to_settings.sh
    ```
   После успешного выполнения команды, появится файл настроек
    ```bash
    $ cat settings.xml
    <settings>
        <servers>
            <server>
                <id>tarantool-io</id>
                <configuration>
                    <httpHeaders>
                        <property>
                            <name>cookie</name>
                            <value>sessionid=2cm25p1gs61ua0d2rgioahcbqyzh3txp</value>
                        </property>
                    </httpHeaders>
                </configuration>
            </server>
        </servers>
    
        <activeProfiles>
            <activeProfile>tarantool-io</activeProfile>
        </activeProfiles>
    
        <profiles>
            <profile>
                <id>tarantool-io</id>
                <repositories>
                    <repository>
                        <id>tarantool-io</id>
                        <url>https://www.tarantool.io/en/accounts/customer_zone/packages/maven</url>
                        <snapshots>
                            <enabled>true</enabled>
                        </snapshots>
                    </repository>
                </repositories>
            </profile>
        </profiles>
    
    </settings>
    ```
2. Используя setting.xml загрузим зависимости проекта
   ```bash
   $ mvn -s settings.xml dependency:resolve
   ```
