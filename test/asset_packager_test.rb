require File.dirname(__FILE__) + '/../../../../config/environment'
require 'test/unit'
require 'mocha'

$asset_packages_yml = YAML.load_file("#{RAILS_ROOT}/vendor/plugins/asset_packager/test/asset_packages.yml")
$asset_base_path = "#{RAILS_ROOT}/vendor/plugins/asset_packager/test/assets"

class AssetPackagerTest < Test::Unit::TestCase
  include Synthesis
  
  def setup
    Synthesis::AssetPackage.any_instance.stubs(:log)
    Synthesis::AssetPackage.build_all
  end
  
  def teardown
    Synthesis::AssetPackage.delete_all
  end
  
  def test_find_by_type
    js_asset_packages = Synthesis::AssetPackage.find_by_type("javascripts")
    assert_equal 2, js_asset_packages.length
    assert_equal "base", js_asset_packages[0].target
    assert_equal ["prototype", "effects", "controls", "dragdrop"], js_asset_packages[0].sources
  end
  
  def test_find_by_target
    package = Synthesis::AssetPackage.find_by_target("javascripts", "base")
    assert_equal "base", package.target
    assert_equal ["prototype", "effects", "controls", "dragdrop"], package.sources
  end
  
  def test_find_by_source
    package = Synthesis::AssetPackage.find_by_source("javascripts", "controls")
    assert_equal "base", package.target
    assert_equal ["prototype", "effects", "controls", "dragdrop"], package.sources
  end
  
  def test_delete_and_build
    Synthesis::AssetPackage.delete_all
    js_package_names = Dir.new("#{$asset_base_path}/javascripts").entries.delete_if { |x| ! (x =~ /\A\w+_packaged.js/) }
    css_package_names = Dir.new("#{$asset_base_path}/stylesheets").entries.delete_if { |x| ! (x =~ /\A\w+_packaged.css/) }
    css_subdir_package_names = Dir.new("#{$asset_base_path}/stylesheets/subdir").entries.delete_if { |x| ! (x =~ /\A\w+_packaged.css/) }
    
    assert_equal 0, js_package_names.length
    assert_equal 0, css_package_names.length
    assert_equal 0, css_subdir_package_names.length

    Synthesis::AssetPackage.build_all
    js_package_names = Dir.new("#{$asset_base_path}/javascripts").entries.delete_if { |x| ! (x =~ /\A\w+_packaged.js/) }.sort
    css_package_names = Dir.new("#{$asset_base_path}/stylesheets").entries.delete_if { |x| ! (x =~ /\A\w+_packaged.css/) }.sort
    css_subdir_package_names = Dir.new("#{$asset_base_path}/stylesheets/subdir").entries.delete_if { |x| ! (x =~ /\A\w+_packaged.css/) }.sort
    
    assert_equal 2, js_package_names.length
    assert_equal 2, css_package_names.length
    assert_equal 1, css_subdir_package_names.length
    assert js_package_names[0].match(/\Abase_packaged.js\z/)
    assert js_package_names[1].match(/\Asecondary_packaged.js\z/)
    assert css_package_names[0].match(/\Abase_packaged.css\z/)
    assert css_package_names[1].match(/\Asecondary_packaged.css\z/)
    assert css_subdir_package_names[0].match(/\Astyles_packaged.css\z/)
  end
  
  def test_js_names_from_sources
    files_and_packages = ["base", "noexist1", "prototype", "foo", "noexist2"]
    expected_names = ["base_packaged", "noexist1", "secondary_packaged", "noexist2"]
    actual_names = Synthesis::AssetPackage.targets_from_sources("javascripts", files_and_packages)
    
    assert_equal expected_names.size, actual_names.size
    expected_names.each_with_index do |expected, index|
      assert_equal expected, actual_names[index], "#{expected} should have been in position #{index}."
    end
  end
  
  def test_css_names_from_sources
    files_and_packages = ["base", "noexist1", "screen", "foo", "noexist2"]
    expected_names = ["base_packaged", "noexist1", "secondary_packaged", "noexist2"]
    actual_names = Synthesis::AssetPackage.targets_from_sources("stylesheets", files_and_packages)
    
    assert_equal expected_names.size, actual_names.size
    expected_names.each_with_index do |expected, index|
      assert_equal expected, actual_names[index], "#{expected} should have been in position #{index}."
    end
  end
  
  def test_sources_from_js_names
    files_and_packages = ["base", "noexist1", "prototype", "foo", "noexist2"]
    expected_names = ["prototype", "effects", "controls", "dragdrop", "noexist1", "foo", "noexist2"]
    actual_names = Synthesis::AssetPackage.sources_from_targets("javascripts", files_and_packages)
    
    assert_equal expected_names.size, actual_names.size
    expected_names.each_with_index do |expected, index|
      assert_equal expected, actual_names[index], "#{expected} should have been in position #{index}."
    end
  end
  
  def test_sources_from_css_names
    files_and_packages = ["base", "noexist1", "screen", "foo", "noexist2"]
    expected_names = ["screen", "header", "noexist1", "foo", "noexist2"]
    actual_names = Synthesis::AssetPackage.sources_from_targets("stylesheets", files_and_packages)
    
    assert_equal expected_names.size, actual_names.size
    expected_names.each_with_index do |expected, index|
      assert_equal expected, actual_names[index], "#{expected} should have been in position #{index}."
    end
  end
  
  def test_should_return_merge_environments_when_set
    Synthesis::AssetPackage.merge_environments = ["staging", "production"]
    assert_equal ["staging", "production"], Synthesis::AssetPackage.merge_environments
  end

  def test_should_only_return_production_merge_environment_when_not_set
    assert_equal ["production"], Synthesis::AssetPackage.merge_environments
  end

  def test_licenses_are_generally_removed_when_compressed
    original_js = File.join($asset_base_path, 'javascripts/application.js')
    
    package = Synthesis::AssetPackage.find_by_source("javascripts", "application")
    packed_js   = File.join($asset_base_path, "javascripts/#{package.target}_packaged.js")
    
    assert File.exists?(original_js), "application.js should exists."
    assert File.exists?(packed_js), "#{package.target}_packaged.js should have been created."
    
    # Make sure the license text is included in application.js but not after packaging
    found_license = false
    File.foreach(original_js) do |line|
      if line.include?("This JavaScript is free.")
        found_license = true
        break
      end
    end
    assert found_license, "Should have found the license."
    
    found_license = false
    File.foreach(packed_js) do |line|
      if line.include?("This JavaScript is free.")
        found_license = true
        break
      end
    end
    assert !found_license, "Should not have found the license."
  end
  
  def test_licenses_in_config_are_included
    original_js = File.join($asset_base_path, 'javascripts/prototype.js')
    
    package = Synthesis::AssetPackage.find_by_source("javascripts", "prototype")
    packed_js   = File.join($asset_base_path, "javascripts/#{package.target}_packaged.js")
    
    assert File.exists?(original_js), "application.js should exists."
    assert File.exists?(packed_js), "#{package.target}_packaged.js should have been created."
    
    # Make sure the license text is included in application.js but not after packaging
    found_license = false
    File.foreach(original_js) do |line|
      if line.include?("Prototype is freely distributable")
        found_license = true
        break
      end
    end
    assert found_license, "Should have found the license."
    
    found_license = false
    File.foreach(packed_js) do |line|
      if line.include?("Prototype is freely distributable")
        found_license = true
        break
      end
    end
    assert found_license, "Should not have found the license."
  end

end
