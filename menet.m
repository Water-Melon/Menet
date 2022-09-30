#include "conf.m"

json = import('json');

eval('admin.m', json.encode(conf['admin']));
eval('manager.m');
eval('server.m', json.encode(conf['tunnel']));
