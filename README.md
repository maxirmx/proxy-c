# proxy-c
### install
* git clone git@github.com:maxirmx/proxy-c.git
* [Ubuntu] apt install ruby-dev ruby-bundler binutils make gcc
* bundle install

### setup id
* create proxy-c/proxy_server/id.rb
```
# frozen_string_literal: true

W_CLIENT_ID = '<your b forum id>'
```

### setup environment
* create ```/var/proxy-c/pids``` folder, make it writable for proxy-c uid
* create ```/var/proxy-c/logs``` folder, make it writable for proxy-c uid

### run
* [will use port 80] puma -C config.rb
