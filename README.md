# systemd-env

Translate from systemd `EnvironmentFile` to POSIX env.

Got a systemd service or one-shot with a complex environment created by multiple environment file entries?
Can't source those files because they're not valid POSIX syntax?
Well, you've come to the right place.

## Install

cp ./systemd-env.sh /usr/sbin/systemd-env

## Usage

Find out what resources your mesos-agent is *actually* gonna use:

```
systemd-env dcos-mesos-slave | grep MESOS_RESOURCES
```

Print the service's env:

```
systemd-env dcos-mesos-slave
```

Run a script or command with a service's environment:

```
./systemd-env.sh dcos-mesos-slave ./script.sh
```

## TODO

Parse `Environment` too, not just `EnvironmentFile`.
