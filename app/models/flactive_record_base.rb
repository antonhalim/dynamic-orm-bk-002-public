require 'pry'
require 'inflecto'
module FlactiveRecord
  class Base

    def self.exec(sql, args=[])
      DBConnection.instance.exec(sql, args)
    end

    def self.connection
      DBConnection.instance.connection
    end

    def self.table_name
      Inflecto.pluralize(name).downcase
    end

    def self.column_names
      result = exec("SELECT column_name FROM information_schema.columns WHERE table_name ='#{table_name}' ORDER BY ordinal_position")
      result.map{|x| x["column_name"]}
    end

    def self.accessor
      column_names.collect{|x| x.to_sym}
    end

    def self.inherited(base)
      base.class_eval do
        attr_accessor *base.accessor
        def initialize(hash={})
          keys = hash.keys
          keys.each do |key|
            self.public_send("#{key}=", hash[key])
          end
        end
      end
    end

    def self.all
      sql = <<-SQL
        SELECT * FROM #{table_name}
      SQL
      results = exec(sql)
      array = results.map{|result| self.new(result)}
    end

    def self.find(id)
      sql = <<-SQL
      SELECT * FROM #{table_name} WHERE id = $1
      SQL
      result = exec(sql, [id]).first
      result ? new(result) : nil
    end

    def save
      if id
        update
      else
        insert
      end
    end

    def insert
      sql = <<-SQL
        INSERT INTO #{self.class.table_name}(#{attributes_for_sql}) VALUES (#{value_for_attributes}) RETURNING id
      SQL
      result = self.class.exec(sql).first
      self.id = result["id"].to_i
    end

    def update
      sql = <<-SQL
        UPDATE #{self.class.table_name} SET #{set_attribute} WHERE id = #{self.id}
      SQL
      self.class.exec(sql)
    end

    def attributes_for_sql
      (self.class.column_names - ["id"]).join(",")
    end

    def value_for_attributes
      attribute = self.class.accessor-[:id]
      attribute.collect{|a|"'"+self.send(a).to_s+"'"}.join(", ")
    end

    def set_attribute
      keys = self.class.column_names - ["id"]
      set_attribute = keys.collect{|x| "#{x} = '#{self.send(x)}'"}.join(", ")
    end


  end
end
