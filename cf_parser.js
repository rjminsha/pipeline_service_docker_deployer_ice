fs = require('fs');

parseconfig = function(configfile, callback){
    fs.readFile(configfile, 'utf8', function (err, data) {
      if (err) {
        throw err;
      }
      cfconfig = JSON.parse(data);
      console.log(cfconfig);
      callback(cfconfig['OrganizationFields'].Name, cfconfig['SpaceFields'].Name, cfconfig.RefreshToken, cfconfig.AccessToken);
    });
}

printInfo = function( org, space, refresh, bearer){
    console.log("Cloud Foundry Information:")
    console.log("org:" + org);
    console.log("space:" + space);
    console.log("refresh:" + refresh);
    console.log("bearer:" + bearer);
}

exportInfo = function( org, space, refresh, bearer ){
    console.log("export CF_BLUEMIX_ORG=" + org);
    console.log("export CF_BLUEMIX_SPACE=" + space);  
}

parseconfig(process.argv[2], exportInfo);



