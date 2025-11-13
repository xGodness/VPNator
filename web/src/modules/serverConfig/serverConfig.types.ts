export const enum VpnProtocol {
  outline = "outline",
  openconnect = "openconnect",
  openvpn = "openvpn"
}

export interface ServerConfig {
  remoteAddress: string;
  username: string;
  password: string;
  protocol: VpnProtocol;
}
