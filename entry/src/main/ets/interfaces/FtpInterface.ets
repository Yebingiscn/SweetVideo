export interface FtpServer {
  id: string
  name: string
  baseUrl: string
  user: string
}

export interface FtpEntry {
  name: string
  directory: boolean
  size: number
}
