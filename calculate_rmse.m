% This function calculates the room mean square error (RMSE) of two datasets (3D)
% Input: Two perfusion maps and mask
% Output: RMSE

function rmse = calculate_rmse(file_1, file_2, mask)

	handle_1    = load_nii(strcat(file_1, '.nii.gz'));
	handle_2    = load_nii(strcat(file_2, '.nii.gz'));
	handle_mask = load_nii(strcat(mask, '.nii.gz'));

	data_1    = handle_1.img;
	data_2    = handle_2.img;
	data_mask = handle_mask.img;

	[x, y, z] = size(data_mask);

	sqaure_sum = 0;
	N = nnz(data_mask); % Number of non-zero elements in mask array

	for i = 1 : x
		for j = 1 : y
			for k = 1 : z

				if(data_mask(i, j, k) > 0)
					sqaure_sum = sqaure_sum + ( data_1(i, j, k) - data_2(i, j, k) ) .^ 2;

				end

			end
		end
	end

	rmse = sqrt(sqaure_sum ./ N);
	
end
