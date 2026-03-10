abstract final class AetherStrings {
  // Connection errors
  static const String connectTimeout  = 'Connection timed out.';
  static const String authFailed      = 'Authentication failed. Check your credentials.';
  static const String networkError    = 'Cannot reach server. Check your network.';
  static const String handshakeError  = 'Connection security error.';
  static const String channelError    = 'Server refused to open a channel.';

  // SFTP errors
  static const String sftpPermDenied  = 'Permission denied.';
  static const String sftpNotFound    = 'File not found.';
  static const String sftpError       = 'Server-side SFTP error.';

  // Terminal
  static const String terminalClosed     = '[Connection closed]';
  static const String terminalReconnect  = 'Reconnect';

  // Docker
  static const String dockerNotFound = 'Docker not detected on this host.\nInstall Docker to enable this feature.';

  // UI labels
  static const String addVps         = 'Add VPS';
  static const String editVps        = 'Edit VPS';
  static const String testConnection = 'Test Connection';
  static const String connect        = 'Connect';
  static const String disconnect     = 'Disconnect';
  static const String disconnectAll  = 'Disconnect All';
  static const String settings       = 'Settings';
  static const String about          = 'About';
  static const String startMenu      = 'Start';
  static const String terminal       = 'Terminal';
  static const String fileManager    = 'Files';
  static const String dockerManager  = 'Docker';
  static const String dashboard      = 'Dashboard';
  static const String deleteConfirm  = 'Are you sure you want to delete this?';
  static const String unlockAether   = 'Unlock Aether';
  static const String copyPublicKey  = 'Public key copied to clipboard.';
  static const String keyWarning     = 'Copy this public key to your server before saving.';
}
