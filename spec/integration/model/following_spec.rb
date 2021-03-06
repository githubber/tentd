require 'spec_helper'

describe TentD::Model::Following do
  let(:following) { Fabricate(:following) }

  describe "#as_json" do
    let(:public_attributes) do
      {
        :id => following.public_id,
        :entity => following.entity,
        :permissions => { :public => following.public }
      }
    end

    context 'without options' do
      it 'should return public attributes' do
        expect(following.as_json).to eq(public_attributes)
      end
    end

    context 'with options[:mac]' do
      it 'should return mac key' do
        expect(following.as_json(:mac => true)).to eq(public_attributes.merge(
          :mac_key_id => following.mac_key_id,
          :mac_key => following.mac_key,
          :mac_algorithm => following.mac_algorithm
        ))
      end
    end

    context 'with options[:groups]' do
      it 'should return groups' do
        expect(following.as_json(:groups => true)).to eq(public_attributes.merge(
          :groups => following.groups
        ))
      end
    end

    context 'with options[:permissions]' do
      let(:follower) { Fabricate(:follower) }
      let(:group) { Fabricate(:group) }
      let(:entity_permission) { Fabricate(:permission, :follower_access => follower) }
      let(:group_permission) { Fabricate(:permission, :group => group) }
      let(:following) { Fabricate(:following, :permissions => [group_permission, entity_permission]) }

      it 'should return detailed permissions' do
        expect(following.as_json(:permissions => true)).to eq(public_attributes.merge(
          :permissions => {
            :public => following.public,
            :groups => [group.public_id],
            :entities => {
              follower.entity => true
            }
          }
        ))
      end
    end

    context 'with options[:app]' do
      it 'should return additional attribtues' do
        expect(following.as_json(:app => true)).to eq(public_attributes.merge(
          :profile => following.profile,
          :licenses => following.licenses,
          :remote_id => nil,
          :updated_at => following.updated_at.to_time.to_i,
          :created_at => following.updated_at.to_time.to_i
        ))
      end
    end
  end

  describe '.update_profile' do
    let(:http_stubs) { Faraday::Adapter::Test::Stubs.new }
    let(:updated_profile) {
      {
        TentD::Model::ProfileInfo::TENT_PROFILE_TYPE_URI => {
          "licenses" => ["http://creativecommons.org/licenses/by/3.0/"],
          "entity" => "https://new-server.example.org",
          "servers" => ["https://new-server.example.org/tent"]
        }
      }
    }
    before { TentClient.any_instance.stubs(:faraday_adapter).returns([:test, http_stubs]) }

    it 'should update a profile' do
      http_stubs.get('/profile') {
        [200, { 'Content-Type' => TentD::API::MEDIA_TYPE }, updated_profile.to_json]
      }
      described_class.update_profile(following.id)
      following.reload

      expect(following.profile).to eq(updated_profile)
      expect(following.licenses).to eq(updated_profile.values.first['licenses'])
      expect(following.entity).to eq(updated_profile.values.first['entity'])
    end
  end
end
