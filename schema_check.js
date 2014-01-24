/**
 * @file   JSON Schema checker on Node.js
 * @author yak_ex@mx.scn.tv
 */
var fs = require('fs');
var repl = require('repl');
var request = require('request');
var r = request.defaults(process.env.http_proxy !== undefined ? {'proxy': process.env.http_proxy} : {});
var tv4 = require('tv4');
var scsc;
var allsc;
var target = 'protocol.md';
var last;
var rp;

function callback(scsc)
{
    var cur = new Date;
    if(last !== undefined && (cur  - last) < 10 * 1000) {
        return;
    }
    last = cur;
    var flag = false;
    console.log('---');
    fs.readFile(target, { 'encoding': 'utf-8' }, function(err, data) {
        var re = /```(?:json)?([^`]*)```/mg;
        var match;
        while(match = re.exec(data)) {
            try {
                var s = JSON.parse(match[1]);
                if(!flag) { flag = true; allsc = s; rp.context.allsc = allsc; }
                console.log(tv4.validateResult(s, scsc));
            } catch (e) {
                console.log(match[1] + e)
            }
        }
    });
}
 
if(scsc === undefined) {
    r.get('http://json-schema.org/draft-04/schema', function(e,r,b) {
        scsc = JSON.parse(b); rp.context.scsc = scsc;
        tv4.addSchema(scsc);
        callback(scsc);
        tv4.addSchema('/', allsc);
        rp.context.tv4 = tv4;
    });
}

fs.watch(target, function(event) {
    callback(scsc);
    tv4.addSchema('/', allsc);
    rp.context.tv4 = tv4;
});
rp = repl.start({});
