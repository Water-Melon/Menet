json = import('json');
sys = import('sys');
net = import('net');
md5 = import('md5');

conf = json.decode(EVAL_DATA);
sys.print('admin listen:' + conf['ip'] + ':' + conf['port']);
fd = net.tcp_listen(conf['ip'], conf['port']);
while (true) {
    connfd = net.tcp_accept(fd);
    tcp = [
        'hash': md5.md5(EVAL_DATA + connfd + sys.time()),
        'fd': connfd
    ];
    eval('http.m', json.encode(tcp));
}
