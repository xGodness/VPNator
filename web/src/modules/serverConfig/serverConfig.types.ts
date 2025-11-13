export const enum VpnProtocol {
  outline = "outline",
  openconnect = "openconnect",
  xray = "xray",
}

export interface ServerConfig {
  remoteAddress: string;
  username: string;
  password: string;
  protocol: VpnProtocol;
  vpnUsername?: string;
  vpnPassword?: string;
}
