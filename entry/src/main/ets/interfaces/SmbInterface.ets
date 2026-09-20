export interface SmbServer {
  id: string
  name: string
  host: string
  port: number
  share: string
  user: string
  domain: string
  seal: boolean
  initialPath?: string
}
