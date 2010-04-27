require 'spec_helper'

describe BigFloat, 'class' do
  subject { BigFloat }
  it { should_not be_respond_to(:new) }
  its(:ancestors) { should be_include(Numeric) }
  its(:instance_methods) { should be_include(:base) }
  its(:instance_methods) { should be_include(:accuracy) }
  its(:instance_methods) { should be_include(:precision) }
end

describe BigFloat::VERSION do
  subject { BigFloat::VERSION }
  it { should == '0.0.1' }
end

describe Kernel do
  subject { Kernel }
  its(:instance_methods) { should be_include(:BigFloat) }
end

describe Kernel, '#BigFloat' do
  context 'with 0' do
    subject { BigFloat(0) }
    it { should == 0 }
    its(:base) { should == 2 }
    its(:accuracy) { should == 0 }
    its(:precision) { should == 0 }
  end

  context 'with (0, base: 10)' do
    subject { BigFloat(0, base: 10) }
    it { should == 0 }
    its(:base) { should == 10 }
    its(:accuracy) { should == 0 }
    its(:precision) { should == 0 }
  end

  [1, *3..9].each do |i|
    context "with (0, base: #{i})" do
      it "should raise ArgumentError" do
        lambda { BigFloat(0, base: i) }.should raise_error(ArgumentError)
      end
    end
  end
end
