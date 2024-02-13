sessionid=$(curl -i --header "User-Agent: tt" -X POST -L https://www.tarantool.io/en/accounts/customer_zone/api --data "{\"username\": \"$USER_NAME\", \"password\": \"$PASSWORD\", \"query\": \"maven\"}" | grep sessionid | awk '{print $2}' | rev | cut -c 2- | rev)
cat >settings.xml <<EOL
<settings>
	<servers>
		<server>
			<id>tarantool-io</id>
			<configuration>
				<httpHeaders>
					<property>
						<name>cookie</name>
						<value>${sessionid}</value>
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
EOL