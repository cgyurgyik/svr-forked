function list = polarCoordinateTraversal(min_bound, max_bound, ray_origin, ray_direction, circle_center, ...
        circle_max_radius, num_radial_sections, num_angular_sections, t_begin, t_end, verbose)
% Input:
%    min_bound: The lower left corner of the bounding box.
%    max_bound: The upper right corner of the bounding box.
%    ray origin: The origin of the ray in (x, y) coordinates.
%    ray direction: The direction of the ray in (x, y) coordinates.
%    circle_center: The x, y location of the center of the circle.
%    circle_max_radius: The largest that encompasses the circle.
%    num_radial_sections: The number of radial sections in the circle.
%    num_angular_sections: The number of angular sections in the circle.
%    t_begin: The beginning time of the ray.
%    t_end: The end time of the ray.
%
% Requires:
%    max_bound > min_bound
%    circle center is within max_bound and min_bound.
%    t_end > t_begin >= 0.0
%    circle_max_radius > 0
%    num_radial_sections > 0
%    num_angular_sections > 0
%
% Returns: 
% The list of voxel indices given by (radial_voxel_ID, angular_voxel_ID).
%
% Notes: 
%    Currently under construction.
    close all;
    circle_center_x = circle_center(1);
    circle_center_y = circle_center(2);
    ray_origin_x = ray_origin(1);
    ray_origin_y = ray_origin(2);
    ray_direction_x = ray_direction(1);
    ray_direction_y = ray_direction(2);
    
    min_bound_x = min_bound(1);
    min_bound_y = min_bound(2);
    max_bound_x = max_bound(1);
    max_bound_y = max_bound(2);
    
    ray_start = ray_origin + t_begin * ray_direction;
    ray_start_x = ray_start(1);
    ray_start_y = ray_start(2);
    
    ray_end = ray_origin + t_end * ray_direction;
    ray_end_x = ray_end(1);
    ray_end_y = ray_end(2);
    
    if (verbose)
        figure;
        hold on;
        title('Polar Coordinate Voxel Traversal')
        
        if (t_begin ~= 0.0)
            % Mark the ray origin if the time does not start at 0.0
            text(ray_origin_x, ray_origin_y, ' ray origin');
            plot(ray_origin_x, ray_origin_y, 'k.', 'MarkerSize', 10);
            quiver(ray_origin_x, ray_origin_y, ray_direction_x, ray_direction_y, t_begin - 0.0, 'LineWidth', 1.5);
        end
        
        % Draw the ray.
        text(ray_start_x, ray_start_y, ' ray start');
        text(ray_end_x, ray_end_y, ' ray end');
        plot(ray_end_x, ray_end_y, 'k.', 'MarkerSize', 10);
        plot(ray_start_x, ray_start_y, 'k.', 'MarkerSize', 10);
        quiver(ray_start_x, ray_start_y, ray_direction_x, ray_direction_y, t_end - t_begin, 'LineWidth', 1.5);
        
        % Draw the axis.
        axis tight;
        xlim([min_bound_x, max_bound_x]);
        ylim([min_bound_y, max_bound_y]);
        xlabel('x');
        ylabel('y');
        grid on;
        
        % Draw the radial sections.
        current_max_radius = circle_max_radius;
        delta_radius = circle_max_radius / num_radial_sections;
        for k = 1:num_radial_sections
            viscircles(circle_center, current_max_radius, 'LineStyle', '--', 'Color', '#7E2F8E', 'LineWidth', 1);
            current_max_radius = current_max_radius - delta_radius;
        end
        
        % Draw the angular sections.
        N = num_angular_sections;
        section = 2 * pi / num_angular_sections;
        for ii = 1:N
              t = linspace(section * (ii - 1), section * (ii));
              x = circle_max_radius*cos(t) + circle_center_x;
              y = circle_max_radius*sin(t) + circle_center_y;
              x = [x circle_center_x x(1)];
              y = [y circle_center_y y(1)];
              line(x, y, 'LineStyle', '--', 'Color', '#7E2F8E', 'LineWidth', 0.5);
        end
    end
    
    % INITIALIZATION PHASE
    %  I. Calculate Voxel ID R.
    delta_radius = circle_max_radius / num_radial_sections;
    current_position = (ray_start_x - circle_center_x)^2 + (ray_start_y - circle_center_y)^2;
    if current_position > circle_max_radius^2
        current_voxel_ID_r = 1;
    else
        current_delta_radius = delta_radius;
        current_voxel_ID_r = num_radial_sections;
        while (current_position > current_delta_radius^2)
            current_voxel_ID_r = current_voxel_ID_r - 1;
            current_delta_radius = current_delta_radius + delta_radius;
        end
    end
    
    % II. Calculate Voxel ID Theta.
    current_voxel_ID_theta = floor(atan2(ray_start_y, ray_start_x) * num_angular_sections / (2 * pi));
    if current_voxel_ID_theta < 0
        current_voxel_ID_theta = num_angular_sections + current_voxel_ID_theta;
    end
    
    list = [[current_voxel_ID_r, current_voxel_ID_theta]];
    
    % TRAVERSAL PHASE
    t = t_begin;
    
    while t < t_end
        % 1. Calculate tMaxR (using radial_hit) 
        [is_radial_hit, tMaxR, tDeltaR, tStepR] = radial_hit(ray_origin, ray_direction, ...
            current_voxel_ID_r, circle_center, circle_max_radius, delta_radius, verbose);
        
        [is_angular_hit, tMaxTheta, tStepTheta] = angular_hit(ray_origin, ray_direction, current_voxel_ID_theta,...
        num_radial_sections, verbose);
    
        % 2. Compare tMaxTheta, tMaxR
        if tMaxTheta < tMaxR
            t = t + tDeltaTheta;
            current_voxel_ID_theta = current_voxel_ID_theta + tStepTheta;
        else
            t = t + tDeltaR;
            current_voxel_ID_r = current_voxel_ID_r + tStepR;   
        end    
    end
    
    list = [list, [current_voxel_ID_r, current_voxel_ID_theta]];
end

function [is_radial_hit, tMaxR, tStepR, new_ray_position] = ...
        radial_hit(ray_origin, ray_direction, ...
        current_radial_voxel, circle_center, ...
        circle_max_radius, delta_radius, verbose)
% Determines whether a radial hit occurs for the given ray.
% Input:
%    ray_origin: The origin of the ray.
%    ray_direction: The direction of the ray.
%    current_radial_voxel: The current radial voxel the ray is located in.
%    circle_center: The center of the circle.
%    circle_max_radius: The max radius of the circle.
%    num_radial_sections: The number of radial sections.
%    delta_radius: The delta of the radial sections.
%
% Returns:
%    is_radial_hit: true if a radial crossing has occurred, false otherwise.
%    tMaxR: is the time at which a hit occurs for the ray at the next point of intersection.
%    tStepR: The direction of step into the next radial voxel, 0, +1, -1
%    new_ray_position: The (x,y) coordinate of the ray after the traversal.
    ray_direction_x = ray_direction(1);
    ray_direction_y = ray_direction(2);
    circle_center_x = circle_center(1);
    circle_center_y = circle_center(2);
    ray_origin_x = ray_origin(1);
    ray_origin_y = ray_origin(2);
    current_radius = circle_max_radius - (delta_radius * (current_radial_voxel - 1));
    
    if verbose
        fprintf('\nradial_hit. \nCurrent Radial Voxel: %d\n', current_radial_voxel);
    end
        
    % (1)   (x - circle_center_x)^2 + (y - circle_center_y)^2 = current_radius^2
    % (2)    x = ray_origin_x + ray_direction_x(t)
    % (3)    y = ray_origin_y + ray_direction_y(t)
    % Plug in x, y in equation (1), then solve for t.
    % To get point of intersection, plug t back in parametric equation of a ray.
    syms cT; % current time
    intersections_t = solve((ray_origin_x + ray_direction_x * cT - circle_center_x)^2 + ...
        (ray_origin_y + ray_direction_y * cT - circle_center_y)^2 ...
        - (current_radius - delta_radius)^2 == 0, cT);
    
    tMaxR = min(double(subs(intersections_t)));
    
    new_x_position = ray_origin_x + ray_direction_x * tMaxR;
    new_y_position = ray_origin_y + ray_direction_y * tMaxR;
    
    if verbose
        fprintf('tMaxR %f\n', tMaxR);
        fprintf('New position: (%f, %f). Calculated by ray_origin + ray_direction * tMaxR.\n ', new_x_position, new_y_position);
    end
    
   % Determine whether is has switched to a new radial voxel.
    distance_from_origin = (new_x_position - circle_center_x)^2 + (new_y_position - circle_center_y);
    
    if verbose
        fprintf("Distance from origin ^2: %f\n",  distance_from_origin);
        fprintf("Current radius ^2: %f\n", current_radius^2);
        fprintf("(Current radius - delta_radius) ^2: %f\n", (current_radius - delta_radius)^2);
    end
    
    if  distance_from_origin >= current_radius^2
        is_radial_hit = true;
        tStepR = -1;
        new_ray_position = [new_x_position new_y_position];
        if verbose
            text(new_x_position, new_y_position, 'POI');
            fprintf('Ray moving toward voxel closer to perimeter (outward).\n');
        end
    elseif  distance_from_origin < (current_radius - delta_radius)^2
            is_radial_hit = true;
            tStepR = +1;
            new_ray_position = [new_x_position new_y_position];
            if verbose
                text(new_x_position, new_y_position, 'POI');
                fprintf('Ray moving toward voxel closer to center (inward).\n');
            end
    else
        is_radial_hit = false;
        tStepR = 0;
        new_ray_position = current_position;
        if verbose
            fprintf('Ray does not traverse to new radial voxel.\n');
        end
    end
    
    if verbose
        fprintf(['new_voxel_ID_r: %d \n' ...
            'is_radial_hit: %d \n' ...
            'tStepR: %d \n'], current_radial_voxel + tStepR, is_radial_hit, tStepR);
    end
end

function [is_angular_hit, tMaxTheta, tStepTheta] = angular_hit(ray_origin, ray_direction, current_voxel_ID,...
        num_radial_sections, verbose)
% Determines whether an angular hit occurs for the given ray.
% Input:
%    ray_origin: vector of the origin of the ray in cartesian coordinate
%    ray_direction: vector of the direction of the ray in cartesian
%                   coordinate
%    current_voxel_ID: the (angular) ID of current voxel
%    num_radial_sections: number of total radial sections on the grid
% Returns:
%    is_angular_hit: true if an angular crossing has occurred, false otherwise.
%    tMaxTheta: is the time at which a hit occurs for the ray at the next point of intersection.
%    tDeltaTheta: TODO
    
    % First calculate the angular interval that current voxID corresponds
    % to
    delta_theta = 2*pi/num_radial_sections;
    interval_theta = [current_voxel_ID * delta_theta, (current_voxel_ID + 1) * delta_theta];
    
    % calculate the x and y components that correspond to the angular
    % boundary for the angular interval
    xmin = cos(min(interval_theta));
    xmax = cos(max(interval_theta));
    ymin = sin(min(interval_theta));
    ymax = sin(max(interval_theta));
    
    %solve the systems Az=b to check for intersection
    Amin = [xmin, -ray_direction(0); ymin, -ray_direction(1)];
    Amax = [xmax, -ray_direction(0); ymax, -ray_direction(1)];
    b = transpose([ray_origin(0), ray_origin(1)]);
    zmin = Amin\b; % inv(Amin) * b
    zmax = Amax\b; % inv(Amax) * b
    
    % We need the radius (r = z[0]) and time (t = z[0]) to be positive or
    % else the intersection is null
    is_angular_hit = true;
    if zmin(0) < 0 || zmin(1) < 0
        is_angular_hit = false;
    end
    if zmax(0) < 0 || zmin(1) < 0
        is_angular_hit = false;
    end
    
    % If we hit the min boundary then we decrement theta, else increment;
    % assign tmaxtheta
    if zmin(0) < 0 || zmin(1) < 0 
        tStepTheta = -1;
        tMaxTheta = zmin(1);
    else
        tStepTheta = 1;
        tMaxTheta = zmax(1);
    end
    if verbose
        fprintf(['tMaxTheta: %d \n' ...
            'is_angular_hit: %d \n' ...
            'tStepTheta: %d \n'], tMaxTheta, is_angular_hit, tStepTheta);
    end
end
