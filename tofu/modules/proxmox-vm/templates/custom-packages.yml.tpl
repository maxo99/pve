# Custom packages
packages:
%{ for pkg in packages ~}
  - ${pkg}
%{ endfor ~}

# Custom scripts
runcmd:
%{ for script in scripts ~}
  - ${script}
%{ endfor ~}
