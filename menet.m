#include "conf.m"

mln_eval('admin.m', mln_json_encode(conf['admin']));
mln_eval('manager.m');
mln_eval('server.m', mln_json_encode(conf['tunnel']));
