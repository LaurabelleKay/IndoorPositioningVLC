clear;
load cam.mat
load camera_parameters.mat;
s = 1; %Loop counter
l = 1; %Result counter
successes = 0;
attempts = 0;
%Set camera parameters
src = getselectedsource(obj);
src.Exposure = -12;
src.Saturation = 128;
%Start video stream
start(obj);
while s == 1
 clearvars -except obj src cameraParams lights s l result ...
 attempts successes
 attempts = attempts + 1;

 %Acquire image
 I = getsnapshot(obj);

 I = undistortImage(I,cameraParams); %Remove radial distortion
 R = I(:,:,1); %Extract red channel
 G = imgaussfilt(R,20); %Blur the image
 BW = imbinarize(G,0.1); %Threshold
 BO = bwareaopen(BW,100); %Remove noise
 R = rgb2gray(I);

 %Get centre and size of white regions in the image
 blobs = regionprops('table',BW,'Centroid',...
 'MajorAxisLength','MinorAxisLength','Orientation');
 centres = blobs.Centroid;
 if size(centres,1) == 0 || size(centres,2) == 0
 continue;
 end

 %Calculate mean size of the blob
 diametres = mean([blobs.MajorAxisLength blobs.MinorAxisLength],2);
 radii = diametres/2;

 %Circle the blobs
 imshow(I);
 hold on
 viscircles(centres,radii);
 plot(centres(:,1),centres(:,2), 'b*');

 r = round(radii);

 lGroup(size(centres,1)).segment = [];
 lGroup(size(centres,1)).ID = [];
 c = round(centres);

 for i = 1:size(centres,1)
 %Extract centre column of circle
 segment= [];

 try segment = R(c(i,2) - r(i): c(i,2) + r(i),c(i,1));
 catch ME
 if (strcmp(ME.identifier,'Index exceeds matrix dimensions.'))
 continue;
 end
 end

 if isempty(segment)== 1
 continue;
 end

 lGroup(i).segment = segment;

 %Find peaks and troughs of segment
 peaks = findpeaks(double(lGroup(i).segment));
 troughs = findpeaks(-double(lGroup(i).segment));
 troughs = abs(troughs);
 tf = peaks > 50;
 tff = troughs > 50;
 meanP = mean(peaks);
 meanT = mean(troughs);
 d = (meanP - meanT)/2; %Distance between them
 threshold = meanP - d;

 threshold = (threshold/255); %Normalise the threshold

 %Binaarize the segment
 lGroup(i).BW = imbinarize(lGroup(i).segment,threshold);
 lGroup(i).coords = centres(i,:);

 end

 if isempty(lGroup(1).segment) == 1
 continue;
 end

 preamble = [1 1 1 0 1];
 for i = 1:size(centres,1)
 start = 1;
 stop = 1;
 try A = lGroup(i).BW; %Extract values
 catch ME
 if (strcmp(ME.identifier,'Reference to non-existent field''BW''.'))
 continue;
 end
 end

 B = A(2:end); %Shift values left
 C = A(1:end-1) - B;
 if isempty(C)== 1
 continue;
 end

 D = find(C ~= 0); %Find transitions

 if isempty(D) == 1
 continue;
 end

 try E = [D(1); D(2:end)-D(1:end-1) ;length(A)-D(end)];

 catch ME
 if (strcmp(ME.identifier,'Index exceeds matrix dimensions.'))
 continue;
 end
 end

 %Set flag based on starting bit
 lGroup(i).flag = ~A(1);
 fl = ~A(1);

 %Find width of preamble and divide by preamble length
 factor = max(E(fl + 1:2:end))/3;
 factor2 = min(E(fl + 2:2:end));
 factor2 = (factor + factor2)/2;
 F = E;
 F(fl + 1:2:end) = round(E(fl + 1:2:end)/factor);
 F(fl + 2:2:end) = round(E(fl + 2:2:end)/factor2);

 %Set any 0 thicknesses to 1
 ff = find(F == 0);
 F(ff) = 1;

 val = ones(sum(F),1);
 lGroup(i).thicknesses = F;

 %Convert from thicknesses to binary array
 for j = 1:size(F,1)
 fl = ~fl;
 start = stop;
 stop = start + F(j);
 val(start:stop-1,1) = fl;
 end

 lGroup(i).bin = val;

 %Find the preamble
 sIndex = strfind(val',preamble);
 if isempty(val) == 1
 continue;
 end

 IDs = ones(1,size(sIndex,2));
 for j = 1:size(sIndex,2)

 %If there aren't up to 5 bits available after the premable,
 %skip
 if(sIndex(j) + 9 > size(val,1))
 data = [0 0 0 0 0];
 continue;
 end

 %Extract next 5 bits as data
 try data = val(sIndex(j) + 4: sIndex(j) + 8);
 catch ME
 if (strcmp(ME.identifier,'Index exceeds matrix
dimensions.'))
 continue;
 end
 end

 try str = num2str(data');

 catch ME
 if (strcmp(ME.identifier,'Undefined function or variable''data''.'))
 continue;
 end
 end

 %Convert from binary to decimal
 try IDs(j) = bin2dec(str);
 catch ME
 if (strcmp(ME.identifier,'Undefined function or variable''str''.'))
 continue;
 end
 end
 end

 %Skip to next iteration if no IDs are found
 if isempty(IDs) == 1
 continue;
 end

 %Find odd IDs and discard them
 odd = find(mod(IDs,2) == 1);
 if isempty(odd) == 0
 IDs(odd) = [];
 end

 %Find outliers and discard them
 outlier = find(isoutlier(IDs) == 1);
 if isempty(outlier)== 0
 IDs(outlier) = [];
 end

 try lGroup(i).ID = IDs(1);
 catch ME
 if (strcmp(ME.identifier,'Index exceeds matrix dimensions.'))
 continue;
 end
 end
 end

 noID = find(cellfun(@isempty,{lGroup.ID}));
 lGroup(noID) = [];

 %If there aren't at least 2 lights, so not attempt to position
 IDs = cat(1,lGroup.ID);
 if size(IDs,1) < 2
 continue;
 end

 load lights.mat;
 FOV = [45.24 57.62];
 imageSize = [720 1280];
 factor = [FOV(2)/imageSize(2) FOV(1)/imageSize(1)];

 %Make middle coherent with coords (x = index 1, y = index 2)
 middle(1) = imageSize(2)/2;
 middle(2) = imageSize(1)/2;

 for i = 1:size(lGroup,2)

 try lGroup(i).diff = lGroup(i).coords - middle;
 catch ME
 if (strcmp(ME.identifier,'Matrix dimensions must agree.'))
 continue;
 end
 end

 %Calculate angle using pixel distance from the centre of the image
 try ang(i,2) = lGroup(i).diff(1) * factor(1);
 catch ME
 if (strcmp(ME.identifier,'Index exceeds matrix dimensions.'))
 continue;
 end
 end
 try ang(i,1) = lGroup(i).diff(2) * factor(2);
 catch ME
 if (strcmp(ME.identifier,'Index exceeds matrix dimensions.'))
 continue;
 end
 end

 %Find the light in the database
 try v = find([lights.ID] == lGroup(i).ID);
 catch ME
 if (strcmp(ME.identifier,'Matrix dimensions must agree.'))
 continue;
 end
 end

 %Extract light location from ID struct
 try loc(i,1) = lights(v).Pos1(1);
 catch ME
 if (strcmp(ME.identifier,'Undefined function or variable''v''.'))
 continue;
 end
 end
 try loc(i,2) = lights(v).Pos1(2);
 catch ME
 if (strcmp(ME.identifier,'Undefined function or variable''v''.'))
 continue;
 end
 end
 end

 if exist('loc','var') == 0
 continue;
 end
 if size(loc,1) < 2
 continue;
 end

 %Call the positioning function with different parameters based on which
 %axis position is the same
 for i = 1:size(loc)
 z_same = find(loc(:,1) == loc(i));
 if size(z_same,1) == 2
 position = calculatepos(z_same,ang,loc,2);
 break;
 end

 x_same = find(loc(:,2) == loc(i + 1));
 if size(x_same,1) == 2
 position = calculatepos(x_same,ang,loc,1);
 break;
 end
 end

 %Convert the position into strings
 if exist('position','var') == 1
 posStrx = strcat('x: ',num2mstr(position(1)));
 posStry = strcat('Y: ',num2mstr(position(2)));
 posStrz = strcat('z: ',num2mstr(position(3)));
 result(l).position = position; %Store result
 l = l + 1;
 successes = successes + 1
 else
 continue;
 end

 hold on %Superimpose output on image
 text(middle(1) - 40,middle(2) - 20 ,posStrx,'color','g');
 text(middle(1) - 40,middle(2) ,posStry,'color','g');
 text(middle(1) - 40,middle(2) + 20 ,posStrz,'color','g');

 %Print output to console
 disp(posStrx);
 disp(posStry);
 disp(PosStrz);
end
