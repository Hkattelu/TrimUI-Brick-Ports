import java.io.*;
import java.nio.file.*;
import com.jpexs.decompiler.flash.SWF;
import com.jpexs.decompiler.flash.abc.ABC;
import com.jpexs.decompiler.flash.abc.avm2.parser.script.AbcIndexing;
import com.jpexs.decompiler.flash.abc.avm2.parser.script.ActionScript3Parser;
import com.jpexs.decompiler.flash.configuration.Configuration;
import com.jpexs.decompiler.flash.tags.*;

/** Original-source-only audio API probe; does not load purchased content. */
class BuildAudioProbe {
    public static void main(String[] args) throws Exception {
        if(args.length<4 || args.length>5)throw new IllegalArgumentException("empty.swf source-directory output.swf playerglobal.swc [--library-only]");
        boolean libraryOnly=args.length==5 && args[4].equals("--library-only");
        Configuration.playerLibLocation.set(args[3]);SWF.initPlayer();SWF swf;
        try(InputStream in=Files.newInputStream(Path.of(args[0]))){swf=new SWF(in,false);}
        for(Tag t:swf.getTags())if(t instanceof FileAttributesTag){((FileAttributesTag)t).actionScript3=true;t.setModified(true);}
        int pos=1;
        for(String name:libraryOnly?new String[]{"AudioPlaybackMode"}:new String[]{"AudioPlaybackMode","AudioRepro"}){
            DoABC2Tag tag=new DoABC2Tag(swf);tag.flags=1;tag.name="original-audio-probe-"+name;swf.addTag(pos++,tag);
            ABC abc=tag.getABC();swf.resetAbcIndex();AbcIndexing index=swf.getAbcIndex();index.selectAbc(abc);
            Path source=Path.of(args[1]).resolve(name+".as");
            new ActionScript3Parser(index).addScript(Files.readString(source),name+".as",0,0,name,abc);tag.setModified(true);
        }
        if(!libraryOnly){SymbolClassTag symbols=new SymbolClassTag(swf);symbols.tags.add(0);symbols.names.add("AudioRepro");swf.addTag(pos,symbols);}
        try(OutputStream out=Files.newOutputStream(Path.of(args[2]),StandardOpenOption.CREATE_NEW)){swf.saveTo(out);}
    }
}
