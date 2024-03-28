/// A type of connection entry
enum ConnectionEntryType {
  ip,
  url,
  @Deprecated('Use [ConnectionEntryType.url] instead')
  apiUrl,
}
