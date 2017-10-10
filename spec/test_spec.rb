describe "Assignment # 1" do

  context "When #2 Creation of tablespaces" do
    context "First one: 1Gb and 3 datafiles" do
      before(:all) do
        @name_of_tablespace = 'GOFAR_TRAVEL'
        plsql.execute <<-SQL
          CREATE TABLESPACE gofar_travel DATAFILE
            'datafile.dbf' SIZE 300M,
            'datafile1.dbf' SIZE 300M,
            'datafile2.dbf' SIZE 400M
        SQL
      end

      it "should create tablespace named gofar_travel" do
        tablespaces_names = plsql.dba_tablespaces.all.map{|row| row[:tablespace_name]}
        expect(tablespaces_names).to include(@name_of_tablespace)
      end

      it "should have 3 datafiles" do
        datafiles = plsql.dba_data_files.all("WHERE TABLESPACE_NAME='#{@name_of_tablespace}'")
        expect(datafiles.size).to eq(3)
      end

      it "should all datafiles sum up 1Gb" do
        datafiles = plsql.dba_data_files.all("WHERE TABLESPACE_NAME='#{@name_of_tablespace}'")
        datafiles.map! do|row|
          row[:bytes]/(1024 * 1024)
        end
        expect(datafiles.reduce(:+)).to be_between(900,1100).inclusive
      end
    end

    context "Second one: 500Mb and 1 datafile" do
      before(:all) do
        @name_of_tablespace = 'TEST_PURPOSES'
        plsql.execute <<-SQL
          CREATE TABLESPACE test_purposes DATAFILE
            'datafile4.dbf' SIZE 500M
        SQL
      end

      it "should create tablespace named test_purposes" do
        tablespaces_names = plsql.dba_tablespaces.all.map{|row| row[:tablespace_name]}
        expect(tablespaces_names).to include(@name_of_tablespace)
      end

      it "should have 1 datafile" do
        datafiles = plsql.dba_data_files.all("WHERE TABLESPACE_NAME='#{@name_of_tablespace}'")
        expect(datafiles.size).to eq(1)
      end

      it "should all datafiles sum up 500Mb" do
        datafiles = plsql.dba_data_files.all("WHERE TABLESPACE_NAME='#{@name_of_tablespace}'")
        datafiles.map! do|row|
          row[:bytes]/(1024 * 1024)
        end
        expect(datafiles.reduce(:+)).to be_between(499,501).inclusive
      end

      after(:all) do
        plsql.execute "DROP TABLESPACE #{@name_of_tablespace} INCLUDING CONTENTS AND DATAFILES"
      end
    end

    context "Third one: Undo 5Mb and 1 datafile" do
      before(:all) do
        @name_of_tablespace = 'UNDOTS1'
        plsql.execute <<-SQL
          CREATE UNDO TABLESPACE undots1
            DATAFILE 'undotbs_1a.dbf'
            SIZE 5M AUTOEXTEND ON
            RETENTION GUARANTEE
        SQL
      end

      it "should create tablespace of type Undo" do
        tablespaces_names = plsql.dba_tablespaces.all.map{|row| row[:tablespace_name]}
        expect(tablespaces_names).to include("USERS")
      end

      it "should have 1 datafile" do
        datafiles = plsql.dba_data_files.all("WHERE TABLESPACE_NAME='#{@name_of_tablespace}'")
        expect(datafiles.size).to eq(1)
      end

      it "should all datafiles sum up 5Mb" do
        datafiles = plsql.dba_data_files.all("WHERE TABLESPACE_NAME='#{@name_of_tablespace}'")
        datafiles.map! do|row|
          row[:bytes]/(1024 * 1024)
        end
        expect(datafiles.reduce(:+)).to be_between(4,6).inclusive
      end

    end
  end

  context "When #3 Set undo tablespace" do
    before(:all) do
      @undo_tbs = "UNDOTS1"
      @default_undo_tbs = "UNDOTBS1"
      plsql.execute "ALTER SYSTEM SET UNDO_TABLESPACE = #{@undo_tbs}"
    end

    it "should use last undo tablespace created" do
      current_undo = plsql.select_one("SELECT value FROM gv$parameter WHERE name = 'undo_tablespace'")
      expect(current_undo).to eq(@undo_tbs)
    end

    after(:all) do
      plsql.execute "ALTER SYSTEM SET UNDO_TABLESPACE = #{@default_undo_tbs}"
      plsql.execute "DROP TABLESPACE #{@undo_tbs} INCLUDING CONTENTS AND DATAFILES"
    end
  end

  context "When #4 and #5 DBA User" do
    before(:all) do
      @username = "DBAUSER"

      plsql.execute <<-SQL
        CREATE USER DBAuser
        IDENTIFIED BY dba1234
        DEFAULT TABLESPACE gofar_travel
        QUOTA UNLIMITED ON gofar_travel
      SQL
    end

    context "Creation of User DBAUSER" do
      it "Should create a new User named: DBAUSER" do
        user = plsql.dba_users.first("WHERE USERNAME='#{@username}'")
        expect(user).not_to be_nil
      end

      it "Should has gofar_travel tablespace as default" do
        user = plsql.dba_users.first("WHERE USERNAME='#{@username}'")
        expect(user[:default_tablespace]).to eq("GOFAR_TRAVEL")
      end

      it "Should has unlimited space on tablespace" do
        user_quota = plsql.dba_ts_quotas.first("WHERE USERNAME='#{@username}'")
        expect(user_quota[:max_bytes]).to eq(-1)
      end
    end
  end

  context "Assigning privileges to DBAUSER" do
    before(:all) do
      @username = "DBAUSER"
      puts plsql.execute "CREATE ROLE conectar"
      puts plsql.execute "GRANT CONNECT, RESOURCE TO conectar"
      puts plsql.execute "GRANT conectar TO DBAuser"
      plsql.execute "COMMIT"
      puts plsql.dba_roles.all("WHERE ROLE='CONECTAR'")
    end

    it "Should have CONNECT role" do
      puts "USER: #{@username}"
      puts "WHERE GRANTEE='#{@username}' AND GRANTED_ROLE='CONNECT'"
      puts plsql.dba_users.first("WHERE USERNAME='#{@username}'")
      connect_privilege = plsql.dba_role_privs.all("WHERE GRANTED_ROLE='CONNECT'")
      puts "*"*100
      puts connect_privilege
      expect(connect_privilege).not_to be_nil
    end

    it "Should have DBA role" do
      dba_privilege = plsql.dba_role_privs.all("WHERE GRANTED_ROLE='DBA'")
      expect(dba_privilege).not_to be_nil
    end
  end

  after(:all) do
    plsql.execute "DROP TABLESPACE GOFAR_TRAVEL INCLUDING CONTENTS AND DATAFILES"
    plsql.execute "DROP USER DBAUSER"
    plsql.execute "DROP ROLE CONECTAR"
  end

end
