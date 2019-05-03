function [ position ] = calculatepos( index,angles,location,v )
l = abs(location(index(1),v) - location(index(2),v));
a = angles(index(1),v);
b = angles(index(2),v);

aa = 90 - abs(a);
bb = 90 - abs(b);

z = l * (sind(aa)*sind(bb))/sind(aa + bb); %calculate z position
p1 = z * tand(a); %Calculate x/y offset
position = ones(3,1);
position(3,1) = z;

%Calculate the 3rd distance and add/subtract accordingly
if v == 1
 c = angles(index(1),2);
 p3 = z * tand(c);
 position(1,1) = location(index(1),2) - p3;
 position(2,1) = location(index(1),v) - p1;
elseif v == 2
 c = angles(index(1),1);
 p3 = z * tand(c);
 position(2,1) = location(index(1),1) - p3;
 position(1,1) = location(index(1),v) - p1;
end
end
