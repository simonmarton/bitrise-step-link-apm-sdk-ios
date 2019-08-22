require_relative './../functions.rb'

describe 'download_library' do
    it 'returns file download is successful' do
        lib_version = "latest"
        
        f = download_library("https://monitoring-sdk.firebaseapp.com/#{lib_version}/libMonitor.a")
        expect(f.original_filename).to eq("libMonitor.a")
       
    end

    it 'raises error if url is 404' do
        lib_version = "nonexistent"
        expect {
            f = download_library("https://monitoring-sdk.firebaseapp.com/#{lib_version}/libMonitor.a")
        }.to raise_error(Down::NotFound)
    end
end