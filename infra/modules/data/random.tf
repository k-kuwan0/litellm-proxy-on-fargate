resource "random_password" "master_key" {
  length  = 48
  special = false
}

resource "random_password" "salt_key" {
  length  = 48
  special = false
}
