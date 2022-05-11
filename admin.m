conf = mln_json_decode(EVAL_DATA);
mln_print('admin listen:' + conf['ip'] + ':' + conf['port']);
fd = mln_tcp_listen(conf['ip'], conf['port']);
while (true) {
    connfd = mln_tcp_accept(fd);
    tcp = [
        'hash': mln_md5(EVAL_DATA + connfd + mln_time()),
        'fd': connfd
    ];
    mln_eval('http.m', mln_json_encode(tcp));
}
