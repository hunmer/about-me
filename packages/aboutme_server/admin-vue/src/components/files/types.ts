export interface FileNode {
  path: string
  name: string
  isFolder: boolean
  size?: number
  updatedAt?: string
  isBinary?: boolean
  children?: FileNode[]
  childrenLoaded: boolean
}
