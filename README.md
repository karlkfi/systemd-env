# systemd-env

Translate from systemd `EnvironmentFile` to POSIX env.

Got a systemd service or one-shot with a complex environment created by multiple environment file entries?
Can't source those files because they're not valid POSIX syntax?
Well, you've come to the right place.

## Install

```
curl --fail --location --silent --show-error \
  https://raw.githubusercontent.com/karlkfi/systemd-env/master/systemd-env.sh | \
  sudo tee /usr/sbin/systemd-env > /dev/null && \
  sudo chmod a+x /usr/sbin/systemd-env
```

## Usage

Print the service's env:

```
systemd-env <service-name>
```

Run a script or command with a service's environment:

```
systemd-env <service-name> <command>
```

## TODO

Parse `Environment` too, not just `EnvironmentFile`.
