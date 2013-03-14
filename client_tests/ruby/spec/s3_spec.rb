require 'aws-sdk'
require 'uuid'
require 'yaml'
require 'helper'

class AWS::S3::AccessControlList::Grant
  def  ==(other)
    @grantee.to_s == other.grantee.to_s and @permission.to_s == other.permission.to_s
  end
end

describe AWS::S3 do
  let(:s3) { AWS::S3.new( s3_conf ) }
  let(:bucket_name) { "aws-sdk-test-" + UUID::generate }
  let(:object_name) { "key-" + UUID::generate }
  let(:grant_public_read) {
    acl = AWS::S3::AccessControlList.new
    acl.grant(:read).to(:uri => 'http://acs.amazonaws.com/groups/global/AllUsers')
    acl.grants.first
  }

  after :each do
    begin
      if s3.buckets[bucket_name].exists?
        if s3.buckets[bucket_name].objects.count > 0
          s3.buckets[bucket_name].objects.each &:delete
        end
        s3.buckets[bucket_name].delete
      end
    rescue Exception => e
      puts e
    end
  end

  describe "when there is no bucket" do
    it "should not find the bucket." do
      s3.buckets[bucket_name].exists?.should == false
    end

    it "should fail on delete operation." do
      lambda{s3.buckets[bucket_name].delete}.should raise_error
    end

    it "should fail on get acl operation" do
      lambda{s3.buckets[bucket_name].acl}.should raise_error
    end
  end

  describe "when there is a bucket" do
    it "should be able to create and delete a bucket" do
      s3.buckets.create(bucket_name).should be_kind_of(AWS::S3::Bucket)
      s3.buckets[bucket_name].exists?.should == true

      lambda{s3.buckets[bucket_name].delete}.should_not raise_error
      s3.buckets[bucket_name].exists?.should == false
    end

    it "should be able to list buckets" do
      s3.buckets.create(bucket_name).should be_kind_of(AWS::S3::Bucket)
      s3.buckets.count.should > 0
    end

    it "should be able to put, get and delete object" do
      s3.buckets.create(bucket_name).should be_kind_of(AWS::S3::Bucket)

      s3.buckets[bucket_name].objects[object_name].write('Rakefile')
      s3.buckets[bucket_name].objects[object_name].exists?.should == true

      s3.buckets[bucket_name].objects[object_name].read.should == 'Rakefile'

      s3.buckets[bucket_name].objects[object_name].delete
      s3.buckets[bucket_name].objects[object_name].exists?.should == false
    end

    it "should be able to put and get bucket ACL" do
      s3.buckets.create(bucket_name, :acl => :public_read).should be_kind_of(AWS::S3::Bucket)
      s3.buckets[bucket_name].acl.grants.include?(grant_public_read).should == true
    end

    it "should be able to put and get object ACL" do
      s3.buckets.create(bucket_name).should be_kind_of(AWS::S3::Bucket)
      s3.buckets[bucket_name].objects[object_name].write('Rakefile', :acl => :public_read)

      s3.buckets[bucket_name].objects[object_name].acl.grants.include?(grant_public_read).should == true
    end

    it "should be able to put object using multipart upload" do
      s3.buckets.create(bucket_name).should be_kind_of(AWS::S3::Bucket)

      temp = new_mb_temp_file 10 # making 10MB file
      s3.buckets[bucket_name].objects[object_name].write(
                                    :file => temp.path,
                                    :multipart_threshold => 1024 * 1024,
                                   )
      s3.buckets[bucket_name].objects[object_name].exists?.should == true
      temp.close
    end
  end
end
