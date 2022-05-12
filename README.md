<p align="center"><img width="108" src="https://github.com/Water-Melon/Melon/blob/master/docs/logo.png?raw=true" alt="Melon logo"></p>
<p align="center"><img src="https://img.shields.io/github/license/Water-Melon/Menet" /></p>
<h1 align="center">Menet</h1>



Menet is a TCP network middleware that can be dynamically modified through HTTP requests.

This is an **experimental** project, do **NOT** use it in production.

Menet is like a combination of `Nginx UNIT` and `FRP`. On the one hand, users can use Menet to build their own tunnel or proxy services like `FRP`, and on the other hand, these services can dynamically configure routing like `Nginx UNIT`.



### Installation

Menet is written by [Melang](https://github.com/Water-Melon/Melang) which is a script language. So we just Install `melang`, please refer to the `README` of `Melang` repository.



### Usage

#### Start the service

```shell
$ melang menet.m
```

#### Configuration

The configuration file is `conf.m`. The code in this file is a Melang array structure.

```
conf = [
    'admin': [ //HTTP API listen address
        'ip': '0.0.0.0', 
        'port': '1234'
    ],
    'tunnel': [ //tunnel server listen address
        'ip': '0.0.0.0',
        'port': '4321'
    ],
];
```

Menet is both a tunnel client and a tunnel server.

#### APIs

There are four APIs:

- tunnel
- service
- bind
- config

##### tunnel

Add or remove a tunnel, and complete the establishment of tunnel TCP and information synchronization.

```
http://ip:port/tunnel
```

- HTTP Method: `POST`|`DELETE`

- HTTP Body:

  ```json
  {
      "name": "tunnel name",
      "dest": ["ip", "port"]
  }
  ```

  `name` will be synchronized to tunnel server automatically.

##### service

Add or remove a service. There are two kinds of services:

- local
- remote

`local` service represents the service that listens on the port locally, and the `remote` service represents which service to establish a TCP connection to.

```
http://ip:port/service
```

- HTTP Method: `POST`|`DELETE`

- HTTP Body:

  ```
  {
      "name": "service name",
      "key": "rc4 key",
      "timeout": 1000, //Connection timeout, in milliseconds. It's optional. If omitted, it means no timeout.
      "type": "local|remote",
      "addr": ["ip", "port"]"
  }
  ```

##### bind

Add or remove a tunnel-service mapping relationship. And of course, because there are two types of services, the mapping relationship is also divided into `local` and `remote`.

If you want to build a tunnel proxy service, you need to set the `bind` of the `local` service (assumed to be named `service1`) and the tunnel (assumed to be named `tunnel1`) on a Menet service, then you need to set up a `remote` service (also named `service1`) and tunnel (also named `tunnel1`) bind on the peer tunnel.

```
http://ip:port/bind
```

- HTTP Method: `POST`|`DELETE`

- HTTP Body:

  ```json
  {
      "tunnel": "tunnel name",
      "service": "service name",
      "type": "local|remote"
  }
  ```

##### config

Display the configuration on Menet service.

```
http://ip:port/config
```

- HTTP Method: `GET`
- HTTP Body: None

##### Example

```
                  |---------------|                      |------------------|
    service1      |192.168.1.2    |        tunnel1       |192.168.1.3       |   service1
----------------> |8080    Menet  |--------------------->|4321      Menet   |-------------->192.168.1.3:80
                  |admin port:1234|                      |admin port:1234   |
                  |---------------|                      |------------------|
```

If we expect to get the 80 service content of 192.168.1.3 by accessing the 8080 port of 192.168.1.2, we need to make the following API calls:

```
$ curl -XPOST -d '{"name":"tunnel1", "dest":["192.168.1.3", "4321"]}' http://192.168.1.2:1234/tunnel
$ curl -XPOST -d '{"name":"service1", "key":"UHI@&s8sa*S", "type": "local", "addr":["0.0.0.0", "8080"]}' http://192.168.1.2:1234/service
$ curl -XPOST -d '{"name":"service1", "key":"UHI@&s8sa*S", "type": "remote", "addr":["192.168.1.3", "80"]}' http://192.168.1.3:1234/service
$ curl -XPOST -d '{"tunnel": "tunnel1", "service":"service1", "type": "local"}' http://192.168.1.2:1234/bind
$ curl -XPOST -d '{"tunnel": "tunnel1", "service":"service1", "type": "remote"}' http://192.168.1.3:1234/bind
```

We don't have to send `tunnel` request to `192.168.1.3`, because the first command will help us to establish TCP and synchronize tunnel name to it.

You can now check the configuration of both Menet services using the `config` request.



### License

[GNU Affero General Public License v3.0](https://github.com/Water-Melon/Menet/blob/master/LICENSE)

Copyright (c) 2022-present, Niklaus F. Schen
