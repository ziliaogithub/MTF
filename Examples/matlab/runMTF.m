close all;
% clear all;
% if isunix
% %     addpath('/home/abhineet/E/UofA/Thesis/Code/TrackingFramework/Matlab/');
% %     addpath('/home/abhineet/E/UofA/Thesis/Code/TrackingFramework/C++/MTF/Build/Release/');
% else
    % addpath('E:\UofA\Thesis\Code\TrackingFramework\Matlab');
% %     addpath('E:\UofA\Thesis\Code\TrackingFramework\C++\MTF\Build\Release');
% end
datasets;
pipeline = 'c';
actor_id = 0;
seq_id = 16;
img_source = 'j';
seq_fmt = 'jpg';

if ~exist('config_dir', 'var')
	config_dir = '../../Config';
end
if ~exist('db_root_dir', 'var')
	db_root_dir = '../../../../../Datasets';
end


use_mtf_pipeline = 1;
init_frame_id = 1;
use_rgb_input = 1;
show_fps = 0;
show_window = 1;

if use_mtf_pipeline
    param_str = sprintf('config_dir %s db_root_dir %s', config_dir, db_root_dir);
    [input_id, n_frames] = mexMTF('create_input', param_str);
    if input_id == 0
        error('MTF input pipeline creation was unsuccessful');
    else
        fprintf('MTF input pipeline created successfully');
        if n_frames > 0
            fprintf(' with %d frames');
        end
        fprintf('\n');
    end
    [success, init_img] = mexMTF('update_input', input_id);
    if ~success
        error('MTF input pipeline update was unsuccessful');
    end
else
    actor = actors{actor_id+1};
    seq_name = sequences{actor_id + 1}{seq_id + 1};
    seq_path = sprintf('%s/%s/%s', db_root_dir, actor, seq_name);
    img_files = dir([seq_path, sprintf('/*.%s', seq_fmt)]);
    n_frames = length(img_files(not([img_files.isdir])));
    init_img_path = sprintf('%s/frame%05d.%s', seq_path, init_frame_id, seq_fmt);
    init_img = imread(init_img_path);
end


tracker_id = mexMTF('create_tracker', config_dir);
if tracker_id == 0
    error('Tracker creation was unsuccessful');
else
    fprintf('Tracker created successfully\n');
end
% pause;

gt_path = sprintf('%s.txt', seq_path);
gt_struct = importdata(gt_path);
gt_data = gt_struct.data;
gt_corners = zeros(2, 4);
gt_corners(1, :) = gt_data(init_frame_id, [1, 3, 5, 7]);
gt_corners(2, :) = gt_data(init_frame_id, [2, 4, 6, 8]);
if ~use_rgb_input
    init_img = rgb2gray(init_img);
end
[success, init_corners] = mexMTF('initialize_tracker', tracker_id, uint8(init_img), double(gt_corners));
if ~success
    error('Tracker initialization was unsuccessful');
else
    fprintf('Tracker initialized successfully\n');
end
% pause
avg_error = 0;
frame_id = init_frame_id + 1
while  1
    if use_mtf_pipeline
        [success, curr_img] = mexMTF('update_input', input_id);
        if ~success
            error('MTF input pipeline update was unsuccessful for frame %d', frame_id + 1);
        end
    else
        img_path = sprintf('%s/frame%05d.%s', seq_path, frame_id, seq_fmt);
        curr_img = imread(img_path); 
    end   
    if ~use_rgb_input
        curr_img = rgb2gray(curr_img);
    end
    start_t = tic;
    [success, curr_corners] = mexMTF('update_tracker', tracker_id, uint8(curr_img));
    time_passed = toc(start_t);
    if ~success
        error('Tracker update was unsuccessful');
    end
	if show_fps
		fps = 1.0 /double(time_passed);
		fprintf('time_passed: %f\t fps: %f\n',time_passed, fps);
    end
    gt_corners(1, :) = gt_data(frame_id, [1, 3, 5, 7]);
    gt_corners(2, :) = gt_data(frame_id, [2, 4, 6, 8]);
	curr_error = norm((gt_corners - curr_corners), 'fro')';
	avg_error = avg_error + (curr_error - avg_error)/(frame_id - init_frame_id);
	if show_window
		imshow(curr_img);
		hold on;
		plot(gt_data(frame_id, [1, 3, 5, 7, 1]), gt_data(frame_id, [2, 4, 6, 8, 2]), 'Color','g', 'LineWidth',2);
		plot([curr_corners(1, :),curr_corners(1, 1)], [curr_corners(2, :), curr_corners(2, 1)], 'Color','r', 'LineWidth',2);
		hold off;
		pause(0.001);
	else
		if mod(frame_id, 50)==0
			fprintf('frame_id: %d\t curr_error: %f\t avg_error: %f\n', frame_id, curr_error, avg_error)
		end
	end
    frame_id = frame_id + 1;
    if n_frames > 0 && frame_id >= n_frames
        break;
    end
end
