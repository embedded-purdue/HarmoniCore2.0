module telephone_tb;

    localparam N = 1024;

    telephone_if #(N) iface();
    telephone #(.N(N)) uut (
        .iface(iface)
    );