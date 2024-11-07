using JLD2: JLD2


function load_cache(file)
    if isfile(file)
        return JLD2.load_object(file)
    else
        return Dict()
    end
end
# TODO: documentation


function save_cache(file, cache)
    tmpfile = "$file~"
    try
        if isfile(file)
            data = JLD2.load_object(file)
            merge!(data, cache)
            JLD2.save_object(tmpfile, data)
        else
            JLD2.save_object(tmpfile, cache)
        end
        Base.Filesystem.cp(tmpfile, file; force = true)
    finally
        Base.Filesystem.rm(tmpfile; force = true)
    end
end
# TODO: documentation
