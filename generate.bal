import ballerina/file;
import ballerina/regex;
import ballerina/io;

public function readExampleFile(file:MetaData[] examples, string bbeFileName, string absPathOfScript) returns string[]?|error {
    foreach file:MetaData example in examples {
        string absPathOfExample = example.absPath;
        
        if absPathOfExample.includes(bbeFileName) {
            string relPathOfExample = check file:relativePath(absPathOfScript, absPathOfExample);
            string[] exampleContent = check io:fileReadLines(relPathOfExample);
            return exampleContent;
        }
    }
    return ();
}

public function extractCodeBlock(string[] exampleContent) returns string[]? {
    string[] codeBlock = [];
    boolean including = false;
    foreach string line in exampleContent {
        if including || line.includes("<div class=\"highlight\">") {
            including = true;
            codeBlock.push(line);

            if line.includes("</pre></div>") {
                return codeBlock;
            }

        }
    }
    return codeBlock;
}

public function extractFrontMatter(string[] exampleContent) returns string[]? {
    string[] frontMatter = [];
    boolean found = false;
    boolean end = false;

    foreach string line in exampleContent {
        if !found && line.includes("---") {
            found = true;
        } else if found && line.includes("---") {
            end = true;
        }

        if found {
            frontMatter.push(line);
        }

        if end {
            return frontMatter;
        }
    }

    return frontMatter;
}

public function concatenateArrays(string[] arr1, string[] arr2) returns string[]? {
    int len1 = arr1.length();
    int len2 = arr2.length();

    string[] newArray = [];

    foreach int i in 0..<len1 {
        newArray.push(arr1[i]);
    }

    foreach int j in 0..<len2 {
        newArray.push(arr2[j]);
    }

    return newArray;
}

public function commentCode(string[] code, int startIndex, int endIndex) returns string[]? {
    code[startIndex] = "<!-- " + code[startIndex];
    code[endIndex] = code[endIndex] + " -->";

    return code;
}

public function uncommentCode(string[] code, int startIndex, int endIndex) returns string[]? {
    code[startIndex] = regex:replaceFirst(code[startIndex], "<!-- ", "");
    code[endIndex] = regex:replaceFirst(code[endIndex], " -->", "");

    return code;
}

public function removeIndex(string line) returns string {
    string corrected = regex:replaceAll(line, "../../categories/([a-z]|-)*/index.html", "#");
    return corrected;
}

public function replaceURL(string line) returns string {
    // leftside
    string leftCorrected = regex:replaceAll(line, "../../categories/([a-z]|-)*", "{{ '/learn/by-example");

    // rightside
    string corrected = regex:replaceAll(leftCorrected, ".html", ".html' | relative_url }}");

    return corrected;
}

public function updateContent(string[] codeBlock, string[] mdbookContent) returns string[]? {
    string[] updatedContent = [];

    boolean removingContent = false;
    boolean codeFound = false;
    boolean removingCode = false;
    boolean outputUpdating = false;
    foreach int i in 0..<mdbookContent.length() {
        string line = mdbookContent[i];

        // removing content
        if !removingContent && line.includes("<!DOCTYPE HTML>") {
            removingContent = true;
        } else if removingContent && line.includes("id=\"sidebar\"") {
            updatedContent.push("<div class=\"mdbook-container\">");
            removingContent = false;
        } else if !removingContent && line.includes("class=\"nav-wrapper\"") {
            removingContent = true;
            updatedContent.push("</div>\n</div>\n</div>\n</div>\n</div>");
        }

        // updating nav class name
        if line.includes("chapter-item") {
            line = regex:replaceAll(line, "chapter-item", "chapter-item bal-nav-item");
        }

        // updating urls
        if line.includes("<a href=\"../../categories/") {
            line = removeIndex(line);
            line = replaceURL(line);
        } 

        // replacing code
        if !codeFound && line.includes("<code class=\"language-go\">") {
            codeFound = true;
            removingCode = true;
        } else if codeFound && line.includes("<h4 id=\"output\">") {
            codeFound = false;
        }

        if !codeFound && !removingCode && !removingContent {
            updatedContent.push(line);
        } else if codeFound && removingCode {
            foreach string codeLine in codeBlock {
                updatedContent.push(codeLine);
            }
            removingCode = false;
        }

        
    }

    foreach int j in 0..<updatedContent.length() {
        int startIndex = 0;
        int endIndex = 0;
        // commenting
        if updatedContent[j].includes("id=\"sidebar-toggle\"") {
            startIndex = j;
            endIndex = j+16;
        } else if updatedContent[j].includes("class=\"menu-title\"") {
            startIndex = j;
            endIndex = j;
        } else if updatedContent[j].includes("href=\"../../print.html\"") {
            startIndex = j;
            endIndex = j+2;
        } else if updatedContent[j].includes("id=\"searchbar-outer\"") {
            startIndex = j;
            endIndex = j+7;
        } 
        
        if startIndex != 0 && endIndex != 0 {
            string[]? commented = commentCode(updatedContent, startIndex, endIndex); 
            if commented != () {
                updatedContent = commented;
            }
        }

        // update header and descriptions
        boolean headerFound = true;
        if updatedContent[j].includes("<a class=\"header\"") {
            updatedContent[j] = regex:replaceFirst(updatedContent[j], "<a class=\"header\"", "<a class=\"bal-header\"");
        } else if headerFound && updatedContent[j].includes("<p>") {
            updatedContent[j] = regex:replaceFirst(updatedContent[j], "<p>", "<p class=\"bal-description\">");
            headerFound = false;
        }

        // minor changes
        if updatedContent[j].includes("<div class=\"highlight\">") {
            updatedContent[j] = regex:replaceFirst(updatedContent[j], "<div class=\"highlight\">", "");
            updatedContent[j] = regex:replaceFirst(updatedContent[j], "<pre>", "<pre><code class=\"code-container\">");    
        } else if updatedContent[j].includes("</pre></div>") {
            updatedContent[j] = regex:replaceFirst(updatedContent[j], "</pre></div>", "</code></pre>");
        } else if updatedContent[j].includes("<main>") {
            updatedContent[j] = regex:replaceFirst(updatedContent[j], "<main>", "<main class=\"bal-container\">");
        }

        // output
        if outputUpdating && !updatedContent[j].includes("</pre>") {
            updatedContent[j] = "<span class=\"bal-output bal-result\">" + updatedContent[j] + "</span>";
        } else if updatedContent[j].includes("</pre>") {
            outputUpdating = false;
        }

        if updatedContent[j].includes("<pre>") && updatedContent[j].includes("<code class=\"language-bash\">") {
            updatedContent[j] = regex:replaceFirst(updatedContent[j], "<pre>", "<pre class=\"output-container\">");
            updatedContent[j] = regex:replaceFirst(updatedContent[j], "<code class=\"language-bash\">", "<code class=\"language-bash\"><span class=\"bal-output bal-execute\">");
            updatedContent[j] = updatedContent[j] + "</span>";
            
            outputUpdating = true;
        }
    }

    return updatedContent;  
}

public function updateFile() returns error? {
    string absPathOfScript = check file:getAbsolutePath("./");
    file:MetaData[] examples = check file:readDir("./inputs/by-example");
    
    // read mdBook files
    file:MetaData[] categories = check file:readDir("./inputs/categories");
    int i = 0;
    foreach file:MetaData category in categories {
        if i != 0 {break;}
        string absPathOfCategory = category.absPath;
        string relPathOfCategory = check file:relativePath(absPathOfScript, absPathOfCategory);
        
        file:MetaData[] mdbookBBEs = check file:readDir(relPathOfCategory);
        
        int j = 0;
        foreach file:MetaData mdbookBBE in mdbookBBEs {
            if j != 0 {break;}
            string absPathOfMdbookBBE = mdbookBBE.absPath;

            if absPathOfMdbookBBE.includes("index.html") {continue;}

            string relPathOfMdBookBBE = check file:relativePath(absPathOfScript, absPathOfMdbookBBE);
            string[] splitted = check file:splitPath(relPathOfMdBookBBE);
            string bbeFileName = splitted[splitted.length()-1];
            
            string[]?|error exampleContent = readExampleFile(examples, bbeFileName, absPathOfScript);
            if exampleContent is error|() {panic error("example reading error");}

            string[]? frontMatter = extractFrontMatter(exampleContent);
            if frontMatter is () {return error("front matter reading error");}
            
            string[]? codeBlock = extractCodeBlock(exampleContent);
            if codeBlock is () {panic error("code block empty");}

            string[] mdbookContent = check io:fileReadLines(relPathOfMdBookBBE);

            string[]? frontMatterAdded = concatenateArrays(frontMatter, mdbookContent);
            if frontMatterAdded == () {panic error("contatenation error");}
            mdbookContent = frontMatterAdded;

            string[]? updatedContent = updateContent(codeBlock, mdbookContent);
            if updatedContent is () {panic error("updated content is empty");}

            check io:fileWriteLinesFromStream("./outputs/test.html", updatedContent.toStream());

            // check io:fileWriteLinesFromStream(relPathOfMdBookBBE, updatedContent.toStream());
            j += 1;
        }
        i += 1;

    }
}

public function main() returns error? {
    check updateFile();
}