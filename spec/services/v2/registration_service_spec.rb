#***** BEGIN LICENSE BLOCK *****
#
#Version: RTV Public License 1.0
#
#The contents of this file are subject to the RTV Public License Version 1.0 (the
#"License"); you may not use this file except in compliance with the License. You
#may obtain a copy of the License at: http://www.osdv.org/license12b/
#
#Software distributed under the License is distributed on an "AS IS" basis,
#WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for the
#specific language governing rights and limitations under the License.
#
#The Original Code is the Online Voter Registration Assistant and Partner Portal.
#
#The Initial Developer of the Original Code is Rock The Vote. Portions created by
#RockTheVote are Copyright (C) RockTheVote. All Rights Reserved. The Original
#Code contains portions Copyright [2008] Open Source Digital Voting Foundation,
#and such portions are licensed to you under this license by Rock the Vote under
#permission of Open Source Digital Voting Foundation.  All Rights Reserved.
#
#Contributor(s): Open Source Digital Voting Foundation, RockTheVote,
#                Pivotal Labs, Oregon State University Open Source Lab.
#
#***** END LICENSE BLOCK *****
require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe V2::RegistrationService do

  describe 'create_record' do
    it 'should raise an error if the language is unknown' do
      lambda { V2::RegistrationService.create_record(:lang => 'unknown') }.should raise_error V2::UnsupportedLanguageError
    end

    it 'should raise an error if the field is unknown' do
      begin
        V2::RegistrationService.create_record(:lang => 'en', :unknown => 'field')
        fail "UnknownAttributeError expected"
      rescue ActiveRecord::UnknownAttributeError => e
        e.message.should == 'unknown attribute: unknown'
      end
    end

    it 'should not know state_id_number field' do
      begin
        V2::RegistrationService.create_record(:lang => 'en', :state_id_number => '1234')
        fail "UnknownAttributeError expected"
      rescue ActiveRecord::UnknownAttributeError => e
        e.message.should == 'unknown attribute: state_id_number'
      end
    end

    it 'should raise validation errors when the record is invalid' do
      begin
        V2::RegistrationService.create_record(:lang => 'en')
        fail 'ValidationError is expected'
      rescue V2::RegistrationService::ValidationError => e
        e.field.should    == 'date_of_birth'
        e.message.should  == "Required"
      end
    end

    it 'should raise an error if the language is unknown even if everything else is bad' do
      lambda {
        V2::RegistrationService.create_record(:lang => 'ex', :home_state_id => 1)
      }.should raise_error V2::UnsupportedLanguageError
    end

    it 'should raise an error if the language is not given' do
      begin
        V2::RegistrationService.create_record(:home_state_id => 'NY')
        fail 'ValidationError is expected'
      rescue V2::RegistrationService::ValidationError => e
        e.field.should    == 'lang'
        e.message.should  == 'Required'
      end
    end

    [1,2].each do |qnum|
      it "should raise an error if answer #{qnum} is provided without question #{qnum}" do
        begin
          V2::RegistrationService.create_record("survey_answer_#{qnum}" => 'An Answer')
          fail 'SurveyQuestionError is expected'
        rescue V2::RegistrationService::SurveyQuestionError => e
          e.message.should == "Question #{qnum} required when Answer #{qnum} provided"
        end
      end
    end
    [1,2].each do |qnum|
      it "should not raise an error if answer #{qnum} is provided with question #{qnum}" do
        begin
          V2::RegistrationService.create_record("survey_answer_#{qnum}" => 'An Answer', "survey_question_#{qnum}"=>"A Question")
        rescue V2::RegistrationService::SurveyQuestionError => e
          fail 'SurveyQuestionError is not expected'
        rescue
        end
      end
    end

    it 'should deal with states passed as strings' do
      lambda {
        V2::RegistrationService.create_record(:mailing_state => "", :home_state => "1", :prev_state => "");
      }.should_not raise_error ActiveRecord::AssociationTypeMismatch
    end

    context 'complete record' do
      before { @reg = Factory(:api_v2_maximal_registrant, :status => 'step_5') }
      before { mock(Registrant).build_from_api_data({}) { @reg } }

      it 'should save the record and generate PDF' do
        mock(@reg).enqueue_complete_registration_via_api
        V2::RegistrationService.create_record({}).should
      end
    end
  end

  describe 'data_to_attrs' do
    specify { V2::RegistrationService.send(:data_to_attrs, {}).should == {} }
    specify { V2::RegistrationService.send(:data_to_attrs, { :lang  => 'ex' }).should == { :locale => 'ex' } }
    specify { V2::RegistrationService.send(:data_to_attrs, { :survey_question_1 => 'q1' }).should == { :original_survey_question_1 => 'q1' } }
    specify { V2::RegistrationService.send(:data_to_attrs, { :survey_question_2 => 'q2' }).should == { :original_survey_question_2 => 'q2' } }
    specify { V2::RegistrationService.send(:data_to_attrs, { :source_tracking_id => 'sourceid' }).should == { :tracking_source => 'sourceid' } }
    specify { V2::RegistrationService.send(:data_to_attrs, { :partner_tracking_id => 'partnertrackid' }).should == { :tracking_id => 'partnertrackid' } }
    specify { V2::RegistrationService.send(:data_to_attrs, { :opt_in_volunteer => true }).should == { :volunteer => true } }
    specify { V2::RegistrationService.send(:data_to_attrs, { :partner_opt_in_volunteer => true }).should == { :partner_volunteer => true } }
    specify { V2::RegistrationService.send(:data_to_attrs, { :home_state_id => 'NY', :mailing_state => 'ca', :prev_state_id => 'Nj' }).should == { :home_state_id => 33, :mailing_state_id => 5, :prev_state_id => 31 } } # See geo_states.csv
    specify { V2::RegistrationService.send(:data_to_attrs, { :id_number => 'id' }).should == { :state_id_number => 'id' } }
  end

  describe 'find_records' do
    it 'should return an error for invalid partner ID' do
      partner = Factory(:partner, :api_key=>"key")
      lambda {
        V2::RegistrationService.find_records(:partner_id => 0, :partner_api_key => partner.api_key)
      }.should raise_error V2::PartnerService::INVALID_PARTNER_OR_API_KEY
    end

    it 'should return an error for invalid api_key' do
      partner = Factory(:partner, :api_key=>"key")
      lambda {
        V2::RegistrationService.find_records(:partner_id => Partner.first.id, :partner_api_key => 'not_the_key')
      }.should raise_error V2::PartnerService::INVALID_PARTNER_OR_API_KEY
    end

    it 'should return the list of registrants' do
      partner = Factory(:partner, :api_key=>"key")
      reg = Factory(:api_v2_maximal_registrant, :partner => partner)

      V2::RegistrationService.find_records(:partner_id => partner.id, :partner_api_key => partner.api_key).should == [
        { :status               => 'complete',
          :create_time          => reg.created_at.to_s,
          :complete_time        => reg.updated_at.to_s,
          :lang                 => reg.locale,
          :first_reg            => reg.first_registration?,
          :home_zip_code        => reg.home_zip_code,
          :us_citizen           => reg.us_citizen?,
          :name_title           => reg.name_title,
          :first_name           => reg.first_name,
          :middle_name          => reg.middle_name,
          :last_name            => reg.last_name,
          :name_suffix          => reg.name_suffix,
          :home_address         => reg.home_address,
          :home_unit            => reg.home_unit,
          :home_city            => reg.home_city,
          :home_state_id        => reg.home_state_id,
          :has_mailing_address  => reg.has_mailing_address,
          :mailing_address      => reg.mailing_address,
          :mailing_unit         => reg.mailing_unit,
          :mailing_city         => reg.mailing_city,
          :mailing_state_id     => reg.mailing_state_id,
          :mailing_zip_code     => reg.mailing_zip_code,
          :race                 => reg.race,
          :party                => reg.party,
          :phone                => reg.phone,
          :phone_type           => reg.phone_type,
          :email_address        => reg.email_address,
          :opt_in_email         => reg.opt_in_email,
          :opt_in_sms           => reg.opt_in_sms,
          :opt_in_volunteer     => reg.volunteer?,
          :partner_opt_in_email => reg.partner_opt_in_email,
          :partner_opt_in_sms   => reg.partner_opt_in_sms,
          :partner_opt_in_volunteer    => reg.partner_volunteer,
          :survey_question_1    => partner.send("survey_question_1_#{reg.locale}"),
          :survey_answer_1      => reg.survey_answer_1,
          :survey_question_2    => partner.send("survey_question_1_#{reg.locale}"),
          :survey_answer_2      => reg.survey_answer_2 }
      ]
    end

    it 'should not list registrants before the since date' do
      partner = Factory(:partner, :api_key=>"key")
      reg = Factory(:api_v2_maximal_registrant, :partner => partner)

      V2::RegistrationService.find_records(:partner_id => partner.id, :partner_api_key => partner.api_key, :since => 1.minute.from_now.to_s).should == []
    end
    
    it 'should filter by email address' do
      partner = Factory(:partner, :api_key=>"key")
      reg = Factory(:api_v2_maximal_registrant, :partner => partner, :email_address=>"test@osdv.org")
      reg2 = Factory(:api_v2_maximal_registrant, :partner => partner, :email_address=>"test2@osdv.org")

      res = V2::RegistrationService.find_records(:partner_id => partner.id, 
        :partner_api_key => partner.api_key, 
        :email => "test@osdv.org")
      res.first[:email_address].should == reg.email_address
      res.should have(1).registrant
      res2 = V2::RegistrationService.find_records(:partner_id => partner.id, 
        :partner_api_key => partner.api_key, 
        :email => "test2@osdv.org")
      res2.first[:email_address].should == reg2.email_address
      res2.should have(1).registrant
    end


    it 'should filter by email address and since date' do
      partner = Factory(:partner, :api_key=>"key")
      reg = Factory(:api_v2_maximal_registrant, :partner => partner, :email_address=>"test@osdv.org")
      reg2 = Factory(:api_v2_maximal_registrant, :partner => partner, :email_address=>"test2@osdv.org")

      V2::RegistrationService.find_records(:partner_id => partner.id, 
        :partner_api_key => partner.api_key, 
        :email => "test@osdv.org",
        :since => 1.minute.from_now.to_s).should == []
        
      res = V2::RegistrationService.find_records(:partner_id => partner.id, 
          :partner_api_key => partner.api_key, 
          :email => "test@osdv.org",
          :since => 1.day.ago.to_s)
      res.first[:email_address].should == reg.email_address
      res.should have(1).registrant
    end


  end

end