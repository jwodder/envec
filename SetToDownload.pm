class SetToDownload {
private:
 QString shortName, longName, url;
 bool import;
public:
 const QString &getShortName() const { return shortName; }
 const QString &getLongName() const { return longName; }
 const QString &getUrl() const { return url; }
 bool getImport() const { return import; }
 void setImport(bool _import) { import = _import; }
 SetToDownload(const QString &_shortName, const QString &_longName, const QString &_url, bool _import)
  : shortName(_shortName), longName(_longName), url(_url), import(_import) { }
};

