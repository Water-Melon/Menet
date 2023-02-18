json = Import('json');
sys = Import('sys');
md5 = Import('md5');
net = Import('net');

conf = json.decode(EVAL_DATA);
sys.print('tunnel listen:' + conf['ip'] + ':' + conf['port']);
fd = net.tcp_listen(conf['ip'], conf['port']);
while (true) {
    connfd = net.tcp_accept(fd);
    tcp = [
        'hash': md5.md5('' + connfd + sys.time()),
        'fd': connfd
    ];
    Eval('tunnels.m', json.encode(tcp));
}

