% This function calculates the standard deviation (SD) of a 3D dataset
% Input: 3D dataset
% Output: standard deviation

function sd = calculate_SD(file_name)

	file_handle = load_nii(strcat(file_name, '.nii.gz'));

	data_nonzeros = nonzeros(file_handle.img);

	sd = std(data_nonzeros);

end
