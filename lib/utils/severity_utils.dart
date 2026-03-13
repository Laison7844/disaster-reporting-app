String getSeverityEmoji(String severity) {
  switch (severity.trim().toUpperCase()) {
    case 'RED':
      return '🔴';
    case 'ORANGE':
      return '🟠';
    case 'YELLOW':
      return '🟡';
    case 'GREEN':
      return '🟢';
    default:
      return '⚪';
  }
}

String getSeverityLabel(String severity) {
  switch (severity.trim().toUpperCase()) {
    case 'RED':
      return 'Critical';
    case 'ORANGE':
      return 'High';
    case 'YELLOW':
      return 'Medium';
    case 'GREEN':
      return 'Low';
    default:
      return 'Unknown';
  }
}

String getSeverityDisplay(String severity) {
  return '${getSeverityEmoji(severity)} ${getSeverityLabel(severity)}';
}
