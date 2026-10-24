from scripts.serve import URL


def test_tunnel_address_is_found_but_cloudflares_api_host_is_not():
    assert not URL.search("ERR failed to request quick Tunnel: Post https://api.trycloudflare.com/tunnel")
    line = "|  https://surround-citysearch-necessity-absent.trycloudflare.com  |"
    assert URL.search(line).group(0) == "https://surround-citysearch-necessity-absent.trycloudflare.com"
