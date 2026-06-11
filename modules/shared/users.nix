{
  pkgs,
  username,
  ...
}:
{
  users.users.${username} = {
    name = username;
    home = if pkgs.stdenv.hostPlatform.isDarwin then "/Users/${username}" else "/home/${username}";
  };
}
