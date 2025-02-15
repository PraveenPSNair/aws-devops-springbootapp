# Configure the AWS Provider
provider "aws" {
  region     = "ap-south-1"
 
}
provider "aws" {
  region     = "ap-southeast-1"
  alias      = "secondary"


}