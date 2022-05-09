conf = mln_json_decode(EVAL_DATA);
mln_print('tunnel listen:' + conf['ip'] + ':' + conf['port']);
fd = mln_tcp_listen(conf['ip'], conf['port']);
while (true) {
    connfd = mln_tcp_accept(fd);
    tcp = [
        'hash': mln_md5('' + connfd + mln_time()),
        'fd': connfd
    ];
    mln_eval('tunnels.m', mln_json_encode(tcp));
}

