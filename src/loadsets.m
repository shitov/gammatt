function Sets = loadsets( Directory, Prefix, Delimiter, Suffix, varargin )
%LOADSETS Loads EEG information from all sets with specific name pattern
%   Loads EEG information from all sets with specific name of form
%   ${prefix}.+${delimiter}[0-9]+.*${suffix}, e.g.
%   if prefix=person_, delimiter=_, suffix=.mat:
%   - person_John_1stTrial.mat
%   - person_John_2ndTrial.mat
%   - person_Jane_3rdTrial.mat
%   will do.
%
%   DEPENDS ON: eeglab

%% initialize input data
Channels     = [];
ProcessorFn  = [];
RawSets      = {};

% load desired channels
if ~isempty(varargin)
    Channels = varargin{1};
end
if length(varargin) > 1
    ProcessorFn = varargin{2};
end


%% main processing, read directory
Files = dir(Directory);

%% iterate over children
for FileOffset = 1:length(Files)
    %% find matching file
    File = Files(FileOffset);
    
    % skip directories
    if File.isdir
        continue;
    end
    
    % check if filename is of given pattern
    [Match, ~, ~, ~, Tokens] = regexp(File.name, ...
        strcat(Prefix, '(.+)', Delimiter, '(\d+).*', Suffix) );
    if isempty(Match) || length(Tokens{1}) < 2
        continue;
    end
    
    %% grep required metainformation from the filename
    Person = Tokens{1}(1);
    Index  = str2double(Tokens{1}(2));
    
    %% load the set
    elem = pop_loadset('filepath', Directory, 'filename', File.name);
    
    %% preprocess the set by splitting it into meaningful structures
    if ~ isempty(Channels)
        %% preinitialize preprocessing inputs
        % grep requested channels
        NeededChannels = GrepChannels(Channels, elem.chanlocs);
        
        %% overwrite loaded element, drop unneeded channels
        % "monkey patching" of some sort
        % see http://en.wikipedia.org/w/index.php?oldid=484042614
        elem.data     = elem.data(NeededChannels, :, :);
        elem.chanlocs = elem.chanlocs(NeededChannels);
        elem.nbchan   = length(NeededChannels);
    end
    
    %% postprocess a set with a given function
    if ~ isempty(ProcessorFn)
        elem = ProcessorFn(elem, Person, Index);
    end
    
    %% accumulate sets into RawSet map of form RawSet{Person}.trial{id}
    % if this person has no entry in our RawSet "map" ...
    setindex = find(arrayfun(@(s) strcmp(s{1}.name, Person), RawSets));
    % ... create one ...
    if isempty(setindex)
        RawSets{end+1} = struct;
        RawSets{end}.name = Person;
        RawSets{end}.trial{Index} = elem;
    % else modify existing
    else
        RawSets{setindex}.trial{Index} = elem;
    end
end

Sets = RawSets;

end

%% function to get indicies of channels with some specific labels
function Indices = GrepChannels(Labels, SourceChannels)

% preallocate indicies
Indices = zeros(length(Labels), 1);

for i = 1:length(Labels)
    for j = 1:length(SourceChannels)
        if strcmp(Labels(i), SourceChannels(j).labels)
            Indices(i) = j;
            break;
        end
    end
end

end