from deoplete.source.base import Base

class Source(Base):
    def __init__(self, vim) -> None:
        Base.__init__(self, vim)
        
        self.name = 'snippy'
        self.mark = '[snippy]'
        self.rank = 1000
        self.input_pattern = r'\w\+$'
        self.min_pattern_length = 1
        self.vars = {}

    def gather_candidates(self, context):
        return self.vim.exec_lua('return require "snippy".get_completion_items()')
