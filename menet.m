#include "conf.m"

json = Import('json');

Eval('admin.m', json.encode(conf['admin']));
Eval('manager.m');
Eval('server.m', json.encode(conf['tunnel']));
