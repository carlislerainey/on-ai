# On Using AI Models for Quantitative Social Science

The emergence of agentic AI^[Such as Anthropic's Claude Code interface and Opus 5.5 model, as of October 2026.] has randically changed how we can conduct quantitative social science.^[Perhaps I should write "computational" social science for this essay, but that's what I mean---social science that combines uses quantitative datasets, data wrangling, and statitical modeling.] It seems clear that we *should* use agentic AI in our work---critics can no longer dispute the benefits. 

But how should we think about how AI models can help? How can we make sure that we do not *underuse* or *overuse* the models? I cannot answer these questions confidently. However, I can say how I am *thinking about* these questions. 

## What We Do (or Perhaps "What We Did")

In social science, we write papers to help other social scientists understand the world. For *quantitive* social science, I think of projects as having three parts:

1. A *dataset*.
2. A *paper*.
3. A *process* that takes the researcher from the dataset to the paper.

I'll focus on this *process* in this essay.

At our best, the process consists of well-documented computer code that implements our principled decisions (that we carefully defend in the paper).

The process is *long*.^[A quick across several replication archives in political sciences suggest that a typical project uses one to six scripts and 500 to 2,500 lines of code. Some use many more scripts and many more lines of code.]

The process is important.^[We might even argue that the *process* is the primary research product. Insert quote about paper being just an advertisement here.]

So what should this process look like---what features should it have? I suggest three. The process should be:

1. *Principled*: the researcher makes reasonable decisions in anayzing their data.
2. *Implemented*: the researcher actually implements those decisions. 
3. *Documented*: the researcher makes it easy to check that they actually impelemented those decisions. 

[CTK: Insert an aside here. "We could imagine, for example, that a researcher comes up with a clever research design, for example, but fails to code an important variable correctly. Or perhaps they did everything correctly, but they pointed-and-clicked their way to their final estimates and left no way to check."]

I've long advocated for what Healy calls "plain text social science" because tools like CSV datasets, R scripts, and LaTeX files make it easier to document your process (and thus easier to implement). As Healy notes: 

> [CTK: insert the healy quote about you should use the tool that make it easy to work correctly.]

This leaves us with two uncontroversial claims:

1. We need to make smart choices, implement those choices, and document those choices.
2. We need to use tools that allow us to achieve those goals.

## Enter AI

AI models enter almost seemlessly into this framework, especially when used agentically. 

It is indisputable that AI models are a tool that can help *implement* our choices *document* those choices. They can write clear and correct R scripts. they create careful records and version-control our work.^[The can also help make principled decisions, but work in this dimmenision is more complicated, I think.]

This is clear: *at a minimum*, we should use AI models *extensively* for error-checking.[CTK: cite P aronow's essay here.]

[CTK: Add these two examples below as an aside.

**Real examples of errors.** 

*Example 1*: A paper describes a prior distribution as "N(0, 2)." From context, "2" refers to a variance. The Stan model uses `normal(0, 2)`, and Stan treats `2` as a standard deviation.  

*Example 2:* A paper describes an complex algorithm implemented in C++. A subtle but important difference exists between the algorithm described in the paper and the algorithm implemented by the C++ code. 

While these errors are nearly impossible for a human to detect, an AI model will discover them almost always.

]

## Mistakes We Can Make

We can make two types of mistakes.

1. We can use AI too little.
2. We can use AI too much (or for the wrong things).

And for PhD students and junior faculty, it is important that they thread this needle.

### Too Little

The risks of too little seem clear: we fail to discover and correct errors that AI models would have detected.

Others seem to think that AI allows us to work faster, incorporate more data, or push further theoretically. Perhaps. 

### Too Much

The risks of too much seem less clear.

First, we might turn over tasks to AI models that should remain deeply involved. Given the current models, I suspect models are not great at things such as justifying the substantive credibility of assumptions used to establish causality (e.g., parallel trends, ) and finding open and important questions. I don't worry much about this, though. I'm actually optimistic that researchers care about the quality of the papers they put out under their name and that we have (or will quickly develop) good ways to filter out "slop."

Second, we might use AI models to quickly complete tasks that ought not be completed at all. Thus, rather than making less work, they make *more* work. It is clear that we can use agents to to lots of tasks very quickly and with many fewer errors. What matters now is that we point those agents towards *worthwhile* tasks. 

[CTK: make this an aside.

Take the example of data collection. Prior to the emergence of agents, extensive data collection was difficult, expensive, and time-consuming. The high costs made us think carefully about what we wanted and why before we went ahead. The difficulty encouraged and rewarded discernment and judgement. With AI agents, extensive data collection is easy, cheap, and can happen while you sleep. The low costs make it easy to "just go ahead" before we've put any thought into the matter. 

]

## An Attitude for the Future

Others seem optimistic that agents will allow researchers to work faster, collect more data, or push theories further. Others are worried about being overwhelmed by slop. My feelings are different.

I'm excited about this: AI agents will allow us to work *more carefully*.^[When I've used them best, I feel like agents have *slowed me down*, not sped me up, without a huge jump in theoretical or empirical ambition.]

And I'm worried about this: AI agents will allow us to haphazardly persue all sorts of computational projects and do things quickly (and with very few errors) that are not worth doing at all.

So here's an attitude for the future: let's continue our work. Let's continue to do work that's worth doing. Let's continue to write papers worth reading. And let's continue to use tools that help us do that work well (even if it slows us down a little).

