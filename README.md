Just some misc bits that help when using Bash/Powershell.

Put helper scripts in a folder, then reference the folder in your main Bashrc or Powershell_Profile

Loads quick and provides a lot of functional shortcuts...  :)

To view .tf files in NotePad++ with apt colouring, go to NP++ > Language > User Defined Language > Define your language
import the Alex_NP_TF_Userdefined.xml

Then when you save a file as .tf you will get colouring on it.. (This is not a proper .tf file, only a plan I output)

with something like: terragrunt plan --no-colour >> myplan.tf

(Specifically for me to read plans in NP++ so I can see what's created, destroyed etc easily...)
