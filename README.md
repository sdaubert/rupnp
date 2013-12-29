RUPNP will be a Ruby UPNP framework.

Its first purpose is to make my first eventmachine development.

## Create a control point
RUPNP will help you to create a UPnP control point (a client) :
```ruby
require 'rupnp'

EM.run do
  # Search for root devices
  cp = RUPNP::ControlPoint(:root)
  cp.start do |new_devices, disappeared_devices|
    new_devices.subscribe do |device|
      # Do what you want here with new devices
      # Services are available through device.services
    end
    disappeared_devices.subscribe do |device|
      # Do what you want here with devices which unsubscribe
    end
  end
end
```
## Create a device
TODO

## `discover` utility
`discover` is a command line utility to act as a control point:
```
$ discover
discover> search ssdp:all
1 devices found
discover> devices[0].class
=> RUPNP::CP::RemoteDevice
discover>
```

The `search` command take an argument : the target for a UPnP M-SEARCH. This
argument may be:
* `ssdp:all`;
* `upnp:rootdevice`;
* a URN as `upnp:{URN}`.
If no argument is given, default to `ssdp:all`.

`discover` use `pry`. So, in `discover`, you can use the power of Pry.