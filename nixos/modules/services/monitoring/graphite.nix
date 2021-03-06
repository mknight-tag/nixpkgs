{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.graphite;
  writeTextOrNull = f: t: if t == null then null else pkgs.writeTextDir f t;

  dataDir = cfg.dataDir;

  graphiteApiConfig = pkgs.writeText "graphite-api.yaml" ''
    time_zone: ${config.time.timeZone}
    search_index: ${dataDir}/index
    ${optionalString (cfg.api.finders != []) ''finders:''}
    ${concatMapStringsSep "\n" (f: "  - " + f.moduleName) cfg.api.finders}
    ${optionalString (cfg.api.functions != []) ''functions:''}
    ${concatMapStringsSep "\n" (f: "  - " + f) cfg.api.functions}
    ${cfg.api.extraConfig}
  '';

  seyrenConfig = {
    SEYREN_URL = cfg.seyren.seyrenUrl;
    MONGO_URL = cfg.seyren.mongoUrl;
    GRAPHITE_URL = cfg.seyren.graphiteUrl;
  } // cfg.seyren.extraConfig;

  configDir = pkgs.buildEnv {
    name = "graphite-config";
    paths = lists.filter (el: el != null) [
      (writeTextOrNull "carbon.conf" cfg.carbon.config)
      (writeTextOrNull "storage-aggregation.conf" cfg.carbon.storageAggregation)
      (writeTextOrNull "storage-schemas.conf" cfg.carbon.storageSchemas)
      (writeTextOrNull "blacklist.conf" cfg.carbon.blacklist)
      (writeTextOrNull "whitelist.conf" cfg.carbon.whitelist)
      (writeTextOrNull "rewrite-rules.conf" cfg.carbon.rewriteRules)
      (writeTextOrNull "relay-rules.conf" cfg.carbon.relayRules)
      (writeTextOrNull "aggregation-rules.conf" cfg.carbon.aggregationRules)
    ];
  };

  carbonOpts = name: with config.ids; ''
    --nodaemon --syslog --prefix=${name} --pidfile ${dataDir}/${name}.pid ${name}
  '';
  carbonEnv = {
    PYTHONPATH = "${pkgs.python27Packages.carbon}/lib/python2.7/site-packages";
    GRAPHITE_ROOT = dataDir;
    GRAPHITE_CONF_DIR = configDir;
    GRAPHITE_STORAGE_DIR = dataDir;
  };

in {

  ###### interface

  options.services.graphite = {
    dataDir = mkOption {
      type = types.path;
      default = "/var/db/graphite";
      description = ''
        Data directory for graphite.
      '';
    };

    web = {
      enable = mkOption {
        description = "Whether to enable graphite web frontend.";
        default = false;
        type = types.uniq types.bool;
      };

      host = mkOption {
        description = "Graphite web frontend listen address.";
        default = "127.0.0.1";
        type = types.str;
      };

      port = mkOption {
        description = "Graphite web frontend port.";
        default = 8080;
        type = types.int;
      };
    };

    api = {
      enable = mkOption {
        description = "Whether to enable graphite api.";
        default = false;
        type = types.uniq types.bool;
      };

      finders = mkOption {
        description = "List of finder plugins load.";
        default = [];
        example = [ pkgs.python27Packages.graphite_influxdb ];
        type = types.listOf types.package;
      };

      functions = mkOption {
        description = "List of functions to load.";
        default = [
          "graphite_api.functions.SeriesFunctions"
          "graphite_api.functions.PieFunctions"
        ];
        type = types.listOf types.str;
      };

      host = mkOption {
        description = "Graphite web service listen address.";
        default = "127.0.0.1";
        type = types.str;
      };

      port = mkOption {
        description = "Graphite api service port.";
        default = 8080;
        type = types.int;
      };

      package = mkOption {
        description = "Package to use for graphite api.";
        default = pkgs.python27Packages.graphite_api;
        type = types.package;
      };

      extraConfig = mkOption {
        description = "Extra configuration for graphite api.";
        default = ''
          whisper:
            directories:
                - ${dataDir}/whisper
        '';
        example = literalExample ''
          allowed_origins:
            - dashboard.example.com
          cheat_times: true
          influxdb:
            host: localhost
            port: 8086
            user: influxdb
            pass: influxdb
            db: metrics
          cache:
            CACHE_TYPE: 'filesystem'
            CACHE_DIR: '/tmp/graphite-api-cache'
        '';
        type = types.str;
      };
    };

    carbon = {
      config = mkOption {
        description = "Content of carbon configuration file.";
        default = ''
          [cache]
          # Listen on localhost by default for security reasons
          UDP_RECEIVER_INTERFACE = 127.0.0.1
          PICKLE_RECEIVER_INTERFACE = 127.0.0.1
          LINE_RECEIVER_INTERFACE = 127.0.0.1
          CACHE_QUERY_INTERFACE = 127.0.0.1
          # Do not log every update
          LOG_UPDATES = False
          LOG_CACHE_HITS = False
        '';
        type = types.str;
      };

      enableCache = mkOption {
        description = "Whether to enable carbon cache, the graphite storage daemon.";
        default = false;
        type = types.uniq types.bool;
      };

      storageAggregation = mkOption {
        description = "Defines how to aggregate data to lower-precision retentions.";
        default = null;
        type = types.uniq (types.nullOr types.string);
        example = ''
          [all_min]
          pattern = \.min$
          xFilesFactor = 0.1
          aggregationMethod = min
        '';
      };

      storageSchemas = mkOption {
        description = "Defines retention rates for storing metrics.";
        default = "";
        type = types.uniq (types.nullOr types.string);
        example = ''
          [apache_busyWorkers]
          pattern = ^servers\.www.*\.workers\.busyWorkers$
          retentions = 15s:7d,1m:21d,15m:5y
        '';
      };

      blacklist = mkOption {
        description = "Any metrics received which match one of the experssions will be dropped.";
        default = null;
        type = types.uniq (types.nullOr types.string);
        example = "^some\.noisy\.metric\.prefix\..*";
      };

      whitelist = mkOption {
        description = "Only metrics received which match one of the experssions will be persisted.";
        default = null;
        type = types.uniq (types.nullOr types.string);
        example = ".*";
      };

      rewriteRules = mkOption {
        description = ''
          Regular expression patterns that can be used to rewrite metric names
          in a search and replace fashion.
        '';
        default = null;
        type = types.uniq (types.nullOr types.string);
        example = ''
          [post]
          _sum$ =
          _avg$ =
        '';
      };

      enableRelay = mkOption {
        description = "Whether to enable carbon relay, the carbon replication and sharding service.";
        default = false;
        type = types.uniq types.bool;
      };

      relayRules = mkOption {
        description = "Relay rules are used to send certain metrics to a certain backend.";
        default = null;
        type = types.uniq (types.nullOr types.string);
        example = ''
          [example]
          pattern = ^mydata\.foo\..+
          servers = 10.1.2.3, 10.1.2.4:2004, myserver.mydomain.com
        '';
      };

      enableAggregator = mkOption {
        description = "Whether to enable carbon agregator, the carbon buffering service.";
        default = false;
        type = types.uniq types.bool;
      };

      aggregationRules = mkOption {
        description = "Defines if and how received metrics will be agregated.";
        default = null;
        type = types.uniq (types.nullOr types.string);
        example = ''
          <env>.applications.<app>.all.requests (60) = sum <env>.applications.<app>.*.requests
          <env>.applications.<app>.all.latency (60) = avg <env>.applications.<app>.*.latency
        '';
      };
    };

    seyren = {
      enable = mkOption {
        description = "Whether to enable seyren service.";
        default = false;
        type = types.uniq types.bool;
      };

      port = mkOption {
        description = "Seyren listening port.";
        default = 8081;
        type = types.int;
      };

      seyrenUrl = mkOption {
        default = "http://localhost:${toString cfg.seyren.port}/";
        description = "Host where seyren is accessible.";
        type = types.str;
      };

      graphiteUrl = mkOption {
        default = "http://${cfg.web.host}:${toString cfg.web.port}";
        description = "Host where graphite service runs.";
        type = types.str;
      };

      mongoUrl = mkOption {
        default = "mongodb://${config.services.mongodb.bind_ip}:27017/seyren";
        description = "Mongodb connection string.";
        type = types.str;
      };

      extraConfig = mkOption {
        default = {};
        description = ''
          Extra seyren configuration. See
          <link xlink:href='https://github.com/scobal/seyren#config' />
        '';
        type = types.attrsOf types.str;
        example = literalExample ''
          {
            GRAPHITE_USERNAME = "user";
            GRAPHITE_PASSWORD = "pass"; 
          }
        '';
      };
    };
  };

  ###### implementation

  config = mkIf (
    cfg.carbon.enableAggregator ||
    cfg.carbon.enableCache ||
    cfg.carbon.enableRelay ||
    cfg.web.enable ||
    cfg.api.enable ||
    cfg.seyren.enable
  ) {
    systemd.services.carbonCache = {
      enable = cfg.carbon.enableCache;
      description = "Graphite Data Storage Backend";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-interfaces.target" ];
      environment = carbonEnv;
      serviceConfig = {
        ExecStart = "${pkgs.twisted}/bin/twistd ${carbonOpts "carbon-cache"}";
        User = "graphite";
        Group = "graphite";
        PermissionsStartOnly = true;
      };
      preStart = ''
        mkdir -p ${cfg.dataDir}/whisper
        chmod 0700 ${cfg.dataDir}/whisper
        chown -R graphite:graphite ${cfg.dataDir}
      '';
    };

    systemd.services.carbonAggregator = {
      enable = cfg.carbon.enableAggregator;
      description = "Carbon Data Aggregator";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-interfaces.target" ];
      environment = carbonEnv;
      serviceConfig = {
        ExecStart = "${pkgs.twisted}/bin/twistd ${carbonOpts "carbon-aggregator"}";
        User = "graphite";
        Group = "graphite";
      };
    };

    systemd.services.carbonRelay = {
      enable = cfg.carbon.enableRelay;
      description = "Carbon Data Relay";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-interfaces.target" ];
      environment = carbonEnv;
      serviceConfig = {
        ExecStart = "${pkgs.twisted}/bin/twistd ${carbonOpts "carbon-relay"}";
        User = "graphite";
        Group = "graphite";
      };
    };

    systemd.services.graphiteWeb = {
      enable = cfg.web.enable;
      description = "Graphite Web Interface";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-interfaces.target" ];
      path = [ pkgs.perl ];
      environment = {
        PYTHONPATH = "${pkgs.python27Packages.graphite_web}/lib/python2.7/site-packages";
        DJANGO_SETTINGS_MODULE = "graphite.settings";
        GRAPHITE_CONF_DIR = configDir;
        GRAPHITE_STORAGE_DIR = dataDir;
      };
      serviceConfig = {
        ExecStart = ''
          ${pkgs.python27Packages.waitress}/bin/waitress-serve \
          --host=${cfg.web.host} --port=${toString cfg.web.port} \
          --call django.core.handlers.wsgi:WSGIHandler'';
        User = "graphite";
        Group = "graphite";
        PermissionsStartOnly = true;
      };
      preStart = ''
        if ! test -e ${dataDir}/db-created; then
          mkdir -p ${dataDir}/{whisper/,log/webapp/}
          chmod 0700 ${dataDir}/{whisper/,log/webapp/}

          # populate database
          ${pkgs.python27Packages.graphite_web}/bin/manage-graphite.py syncdb --noinput

          # create index
          ${pkgs.python27Packages.graphite_web}/bin/build-index.sh

          touch ${dataDir}/db-created

          chown -R graphite:graphite ${cfg.dataDir}
        fi
      '';
    };

    systemd.services.graphiteApi = {
      enable = cfg.api.enable;
      description = "Graphite Api Interface";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-interfaces.target" ];
      environment = {
        PYTHONPATH =
          "${cfg.api.package}/lib/python2.7/site-packages:" +
          concatMapStringsSep ":" (f: f + "/lib/python2.7/site-packages") cfg.api.finders;
        GRAPHITE_API_CONFIG = graphiteApiConfig;
        LD_LIBRARY_PATH = "${pkgs.cairo}/lib";
      };
      serviceConfig = {
        ExecStart = ''
          ${pkgs.python27Packages.waitress}/bin/waitress-serve \
          --host=${cfg.api.host} --port=${toString cfg.api.port} \
          graphite_api.app:app 
        '';
        User = "graphite";
        Group = "graphite";
        PermissionsStartOnly = true;
      };
      preStart = ''
        if ! test -e ${dataDir}/db-created; then
          mkdir -p ${dataDir}/cache/
          chmod 0700 ${dataDir}/cache/

          touch ${dataDir}/db-created

          chown -R graphite:graphite ${cfg.dataDir}
        fi
      '';
    };

    systemd.services.seyren = {
      enable = cfg.seyren.enable;
      description = "Graphite Alerting Dashboard";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-interfaces.target" "mongodb.service" ];
      environment = seyrenConfig;
      serviceConfig = {
        ExecStart = "${pkgs.seyren}/bin/seyren -httpPort ${toString cfg.seyren.port}";
        WorkingDirectory = dataDir;
        User = "graphite";
        Group = "graphite"; 
      };
      preStart = ''
        if ! test -e ${dataDir}/db-created; then
          mkdir -p ${dataDir}
          chown -R graphite:graphite ${dataDir}
        fi
      '';
    };

    services.mongodb.enable = mkDefault cfg.seyren.enable;

    environment.systemPackages = [
      pkgs.pythonPackages.carbon
      pkgs.python27Packages.graphite_web
      pkgs.python27Packages.waitress
    ];

    users.extraUsers = singleton {
      name = "graphite";
      uid = config.ids.uids.graphite;
      description = "Graphite daemon user";
      home = dataDir;
    };
    users.extraGroups.graphite.gid = config.ids.gids.graphite;
  };
}
