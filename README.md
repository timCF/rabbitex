Rabbitex
========

Very simple otp-app to send messages to RabbitMQ.

Usage:

just init pool (maybe in start func of your app)
```
Rabbitex.init(%{username: "guest", password: "password", host: "127.0.0.1"})
``` 
or
```
Rabbitex.init(%{username: "guest", password: "password", host: "127.0.0.1"}, :other_pool)
``` 
or
```
Rabbitex.init(%{username: "guest", password: "password", host: "127.0.0.1", virtual_host: "/some", heartbeat: 1, size: 100}, :other_pool)
```


And send messages from any part of your app like this:



```
Rabbitex.send("Hello, world!", "some_exchange")
``` 
or
```
Rabbitex.send(%SomeStruct{key: "Hello, world!"}, "some_exchange", "some_routing_key", :other_pool)
``` 
or even
```
Rabbitex.send([key: "Hello, world!"], "some_exchange", "some_routing_key", :other_pool)
```


you can send binary data or any hash dict or struct (it will jsonify)