# A paper to look at on a fresh desk: two drafts, the first marked up, the second published.
return if Rails.env.production? || Paper.exists?

paper = Paper.write \
  title: "On writing slowly",
  author: "A. Typist",
  body: <<~HTML
    <p>There is a kind of thinking that only happens at the speed of a key coming down. You cannot take it back, so you choose it first.</p>
    <h2>The page</h2>
    <p>The page fills from the top. Mistakes stay where they fell, and that is <i>fine</i>. They are the record of getting somewhere.</p>
    <ul><li>Type it once.</li><li>Mark it up.</li><li>Type it again, better.</li></ul>
  HTML

first = paper.latest_draft
first.marks.create!(kind: "line", color: "yellow", points: [ [ 110, 300 ], [ 520, 300 ] ])
first.marks.create!(kind: "stroke", color: "red", points: [ [ 690, 452 ], [ 760, 440 ], [ 820, 470 ], [ 800, 520 ] ])
first.marks.create!(kind: "word", color: "red", points: [ [ 700, 540 ] ], text: "say less?")
first.marks.create!(kind: "line", color: "green", points: [ [ 110, 637 ], [ 380, 637 ] ])

paper.draft \
  title: "On writing slowly",
  author: "A. Typist",
  body: <<~HTML
    <p>Some thinking only happens at the speed of a key coming down. You can't take it back, so you choose it first.</p>
    <h2>The page</h2>
    <p>Mistakes stay where they fell. They are the record of getting somewhere.</p>
    <ul><li>Type it once.</li><li>Mark it up.</li><li>Type it again, <b>better</b>.</li></ul>
  HTML

paper.publish
