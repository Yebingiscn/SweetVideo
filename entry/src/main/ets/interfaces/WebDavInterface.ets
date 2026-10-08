export interface WebDavServer {
  id: string
  name: string
  baseUrl: string
  user: string
}

export interface WebDavEntry {
  name: string
  path: string
  directory: boolean
  size: number
}
