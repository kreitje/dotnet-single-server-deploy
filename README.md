# dotnet-single-server-deploy
Ruby scripts to extract a dotnet app, and deploy on a single Ubuntu server with zero downtime

This project is a deployment tool hosted on the remote server to handle zero downtime deploys of a .net application on a single server.  
It expects you are running 2+ instances of the application, will remove them from the webserver upstream, stop the service, replace the files, 
start the service and put it back in the upstream. After that it will move on to the next app.

## Config.yml
webserver - currently only supports 'caddy'. You must define a webserver as we plan to support multiple webservers in the near future.

app_dll - is the project name.dll.  This is used in the install command when writing the service files

root_path - is the main path to your app. During the install command several directories will be created including a shared folder, and releases folder. 

update_zip_absolute_path - is the absolute path to the new zip version we will deploy.  It gets unzipped in the [root_path]/releases/[timestamp] folder

caddy_upstream_key - this is the id given to the caddy reverse proxy section so we can easily replace the upstreams.

healthcheck - this is the relative path in the dotnet url to hit for a healthcheck. It must return a 200 HTTP status

shared_files - this is an array of files to copy from the [root_path]/shared folder on each deploy

servers - this is a list of the dotnet apps running and what port they are on. We will copy the files from the release folder, and the health check will attempt http://localhost:[port]/[healthcheck] to determine when the app is running


```yaml
webserver: caddy
app_dll: DotnetApp.dll
root_path: /var/www/app1
update_zip_absolute_path: /home/ubuntu/DotnetApp.zip
caddy_upstream_key: dotnetcore
healthcheck: /test
shared_files:
  - appsettings.Production.json
servers:
  - port: 5150
    path: /var/www/app1/app_5150
  - port: 5151
    path: /var/www/app1/app_5151

```


## Caddy Webserver
You must specify an id on the Caddy reverse_proxy so we can send a patch request adding/removing directly to the upstream instead of at the app level.

*Example Caddy Configuration with an id on the reverse_proxy*
```json
{
  "apps": {
    "http": {
      "servers": {
        "web": {

          "listen": [":80"],
          "routes": [
            {

              "match": [
                {
                  "host": ["example.com"]
                }
              ],
              "handle": [
                {
                  "@id": "dotnetcore",
                  "handler": "reverse_proxy",
                  "transport": {
                    "protocol": "http"
                  },
                  "upstreams": [
                    {
                      "dial": "127.0.0.1:5150"
                    },
                    {
                      "dial": "127.0.0.1:5151"
                    }
                  ],
                  "health_checks": {
                    "active": {
                      "uri": "/test",
                      "interval": "1s"
                    },
                    "passive": {
                      "fail_duration": "300ms"
                    }
                  }
                  
                }
              ],
              "terminal": false
            }
          ]
        }
      }

    }
  }
}
```
