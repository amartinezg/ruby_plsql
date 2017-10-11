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
        DEFAULT TABLESPACE GOFAR_TRAVEL
        QUOTA UNLIMITED ON GOFAR_TRAVEL
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

    context "Assigning privileges to DBAUSER" do
      before(:all) do
        @username = "DBAUSER"
        plsql.execute "CREATE ROLE conectar"
        plsql.execute "GRANT CONNECT, RESOURCE TO conectar"
        plsql.execute "GRANT conectar TO DBAuser"
      end

      it "Should have CONNECT role" do
        connect_role = plsql.dba_role_privs.first("WHERE GRANTEE='#{@username}' AND GRANTED_ROLE = 'CONNECT'")
        connect_role ||= plsql.role_role_privs.first("WHERE GRANTED_ROLE='CONNECT' AND ROLE IN (SELECT GRANTED_ROLE FROM DBA_ROLE_PRIVS WHERE GRANTEE='#{@username}')")
        expect(connect_role).not_to be_nil
      end

      it "Should have DBA role" do
        dba_privilege = plsql.dba_role_privs.first("WHERE GRANTEE='#{@username}' AND GRANTED_ROLE = 'DBA'")
        dba_privilege ||= plsql.role_role_privs.first("WHERE GRANTED_ROLE='DBA' AND ROLE IN (SELECT GRANTED_ROLE FROM DBA_ROLE_PRIVS WHERE GRANTEE='#{@username}')")
        expect(dba_privilege).not_to be_nil
      end
    end
  end

  context "When #6 #7 and #8" do
    context "Creation of profiles Manager, Finance and development" do
      context "Manager profile" do
        before(:all) do
          @original_name = 'MANAGER'
          @given_name = 'PERFIL_MANAGER'
          plsql.execute <<-SQL
            CREATE PROFILE perfil_manager LIMIT
            SESSIONS_PER_USER          1
            PASSWORD_LIFE_TIME         40
            IDLE_TIME                  15
            FAILED_LOGIN_ATTEMPTS      4
          SQL
        end

        it "should create a profile with name 'Manager'" do
          profiles = plsql.dba_profiles.all.map{|row| row[:profile]}.uniq
          expect(profiles).to include(@original_name)
        end

        it "should have a password life of 40 days" do
          profile = plsql.dba_profiles.first("WHERE PROFILE='#{@given_name}' AND RESOURCE_NAME = 'PASSWORD_LIFE_TIME'")
          expect(profile[:limit]).to eq("40")
        end

        it "should have one session per user" do
          profile = plsql.dba_profiles.first("WHERE PROFILE='#{@given_name}' AND RESOURCE_NAME = 'SESSIONS_PER_USER'")
          expect(profile[:limit]).to eq("1")
        end

        it "should have 15 minutes idle" do
          profile = plsql.dba_profiles.first("WHERE PROFILE='#{@given_name}' AND RESOURCE_NAME = 'IDLE_TIME'")
          expect(profile[:limit]).to eq("15")
        end

        it "should have 4 failed login attempts" do
          profile = plsql.dba_profiles.first("WHERE PROFILE='#{@given_name}' AND RESOURCE_NAME = 'FAILED_LOGIN_ATTEMPTS'")
          expect(profile[:limit]).to eq("4")
        end
      end

      context "finance profile" do
        before(:all) do
          @original_name = 'FINANCE'
          @given_name = 'PERFIL_FINANCE'
          plsql.execute <<-SQL
            CREATE PROFILE perfil_finance LIMIT
            SESSIONS_PER_USER          1
            PASSWORD_LIFE_TIME         15
            IDLE_TIME                  3
            FAILED_LOGIN_ATTEMPTS      2
          SQL
        end

        it "should create a profile with name 'Finance'" do
          profiles = plsql.dba_profiles.all.map{|row| row[:profile]}.uniq
          expect(profiles).to include(@original_name)
        end

        it "should have a password life of 15 days" do
          profile = plsql.dba_profiles.first("WHERE PROFILE='#{@given_name}' AND RESOURCE_NAME = 'PASSWORD_LIFE_TIME'")
          expect(profile[:limit]).to eq("15")
        end

        it "should have one session per user" do
          profile = plsql.dba_profiles.first("WHERE PROFILE='#{@given_name}' AND RESOURCE_NAME = 'SESSIONS_PER_USER'")
          expect(profile[:limit]).to eq("1")
        end

        it "should have 3 minutes idle" do
          profile = plsql.dba_profiles.first("WHERE PROFILE='#{@given_name}' AND RESOURCE_NAME = 'IDLE_TIME'")
          expect(profile[:limit]).to eq("3")
        end

        it "should have 2 failed login attempts" do
          profile = plsql.dba_profiles.first("WHERE PROFILE='#{@given_name}' AND RESOURCE_NAME = 'FAILED_LOGIN_ATTEMPTS'")
          expect(profile[:limit]).to eq("2")
        end
      end

      context "finance profile" do
        before(:all) do
          @original_name = 'DEVELOPMENT'
          @given_name = 'PERFIL_DEVELOPMENT'
          plsql.execute <<-SQL
            CREATE PROFILE perfil_development LIMIT
            SESSIONS_PER_USER          2
            PASSWORD_LIFE_TIME         100
            IDLE_TIME                  30
          SQL
        end

        it "should create a profile with name 'development'" do
          profiles = plsql.dba_profiles.all.map{|row| row[:profile]}.uniq
          expect(profiles).to include(@original_name)
        end

        it "should have a password life of 100 days" do
          profile = plsql.dba_profiles.first("WHERE PROFILE='#{@given_name}' AND RESOURCE_NAME = 'PASSWORD_LIFE_TIME'")
          expect(profile[:limit]).to eq("100")
        end

        it "should have 2 sessions per user" do
          profile = plsql.dba_profiles.first("WHERE PROFILE='#{@given_name}' AND RESOURCE_NAME = 'SESSIONS_PER_USER'")
          expect(profile[:limit]).to eq("2")
        end

        it "should have 30 minutes idle" do
          profile = plsql.dba_profiles.first("WHERE PROFILE='#{@given_name}' AND RESOURCE_NAME = 'IDLE_TIME'")
          expect(profile[:limit]).to eq("30")
        end

        it "should have NO failed login attempts" do
          profile = plsql.dba_profiles.first("WHERE PROFILE='#{@given_name}' AND RESOURCE_NAME = 'FAILED_LOGIN_ATTEMPTS'")
          expect(profile[:limit]).to eq("UNLIMITED")
        end
      end
    end

    context "Creation of 4 users and assign profiles to them" do
      before(:all) do
        @number_of_users = plsql.dba_users.count
        @original_users = "'"+plsql.dba_users.all.map{|row| row[:username]}.join("','")+"'"
        plsql.execute <<-SQL
          CREATE USER User1
          IDENTIFIED BY User1123
          DEFAULT TABLESPACE GOFAR_TRAVEL
          PROFILE perfil_manager
        SQL
        plsql.execute <<-SQL
          GRANT CONNECT TO User1
        SQL
        plsql.execute <<-SQL
          CREATE USER User2
          IDENTIFIED BY User2123
          DEFAULT TABLESPACE GOFAR_TRAVEL
          PROFILE perfil_finance
        SQL
        plsql.execute <<-SQL
          GRANT CONNECT TO User2
        SQL
        plsql.execute <<-SQL
          CREATE USER User3
          IDENTIFIED BY User3123
          DEFAULT TABLESPACE GOFAR_TRAVEL
          PROFILE perfil_development
        SQL
        plsql.execute <<-SQL
          GRANT CONNECT TO User3
        SQL
        plsql.execute <<-SQL
          CREATE USER User4
          IDENTIFIED BY User4123
          DEFAULT TABLESPACE GOFAR_TRAVEL
          PROFILE perfil_development
        SQL
        plsql.execute <<-SQL
          GRANT CONNECT TO User4
        SQL
        @new_users = plsql.dba_users.all("WHERE USERNAME NOT IN (#{@original_users})")
        @where_new_users = "'"+@new_users.map{|row| row[:username]}.join("','")+"'"
      end

      it "Should create 4 new users" do
        expect(plsql.dba_users.count).to eq(@number_of_users+4)
      end

      it "Should belong to GOFAR_TRAVEL tablespace" do
        expect(@new_users.map{|row| row[:default_tablespace]}.uniq.first).to eq("GOFAR_TRAVEL")
      end

      it "Should have profiles assigned" do
        profiles_of_new_users = @new_users.map{|row| row[:profile].downcase}
        expect(profiles_of_new_users.size).to eq(4)
        expect(profiles_of_new_users).to include("perfil_manager")
        expect(profiles_of_new_users).to include("perfil_finance")
        expect(profiles_of_new_users).to include("perfil_development")
      end

      it "Should have CONNECT role assigned" do
        connect_role = plsql.dba_role_privs.all("WHERE GRANTEE IN (#{@where_new_users}) AND GRANTED_ROLE = 'CONNECT'")
        connect_role ||= plsql.role_role_privs.all("WHERE GRANTED_ROLE='CONNECT' AND ROLE IN (SELECT GRANTED_ROLE FROM DBA_ROLE_PRIVS WHERE GRANTEE IN (#{@where_new_users}))")
        roles_assigned = connect_role.map{|row| row[:granted_role]}.uniq
        expect(roles_assigned).not_to be_nil
        expect(roles_assigned.size).to eq(1)
        expect(roles_assigned.first).to eq("CONNECT")
      end
    end

    context "Locking users with profiles: manager and finance" do
      before(:all) do
        plsql.execute("ALTER USER User1 ACCOUNT LOCK")
        plsql.execute("ALTER USER User2 ACCOUNT LOCK")
      end

      it "Account status should be 'LOCKED'" do
        users_affected = plsql.dba_users.all("WHERE PROFILE IN ('PERFIL_MANAGER','PERFIL_FINANCE')")
        expect(users_affected.size).to eq(2)
        expect(users_affected.map{|row| row[:account_status]}.uniq.first).to eq("LOCKED")
      end
    end
  end

  after(:all) do
    plsql.execute "DROP USER DBAUSER"
    plsql.execute "DROP ROLE CONECTAR"
    plsql.execute "DROP USER USER1"
    plsql.execute "DROP USER USER2"
    plsql.execute "DROP USER USER3"
    plsql.execute "DROP USER USER4"
    plsql.execute "DROP PROFILE PERFIL_MANAGER"
    plsql.execute "DROP PROFILE PERFIL_FINANCE"
    plsql.execute "DROP PROFILE PERFIL_DEVELOPMENT"
    plsql.execute "DROP TABLESPACE GOFAR_TRAVEL INCLUDING CONTENTS AND DATAFILES"
  end

end
