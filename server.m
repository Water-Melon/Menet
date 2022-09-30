json = import('json');
sys = import('sys');
md5 = import('md5');
net = import('net');

conf = json.decode(EVAL_DATA);
sys.print('tunnel listen:' + conf['ip'] + ':' + conf['port']);
fd = net.tcp_listen(conf['ip'], conf['port']);
while (true) {
    connfd = net.tcp_accept(fd);
    tcp = [
        'hash': md5.md5('' + connfd + sys.time()),
        'fd': connfd
    ];
    eval('tunnels.m', json.encode(tcp));
}

