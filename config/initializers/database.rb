Rails.application.config.after_initialize do
  ActiveRecord::Base.connection_pool.with_connection do |conn|
    if conn.adapter_name == "SQLite"
      conn.raw_connection.execute("PRAGMA journal_mode=WAL")
      conn.raw_connection.execute("PRAGMA synchronous=NORMAL")
      conn.raw_connection.execute("PRAGMA foreign_keys=ON")
    end
  end
end
