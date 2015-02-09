/**
* Copyright 2014 IBM
*
*   Licensed under the Apache License, Version 2.0 (the "License");
*   you may not use this file except in compliance with the License.
*   You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
*   Unless required by applicable law or agreed to in writing, software
*   distributed under the License is distributed on an "AS IS" BASIS,
*   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
*   See the License for the specific language governing permissions and
**/
fs = require('fs');

parseconfig = function(configfile, callback){
    fs.readFile(configfile, 'utf8', function (err, data) {
      if (err) {
        throw err;
      }
      cfconfig = JSON.parse(data);
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



